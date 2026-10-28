#!/usr/bin/env python3
"""Damage hints on listing photos from a free, local image model (P.2).

OpenAI's CLIP ViT-B/32 (MIT licence, ONNX export from Hugging Face,
downloaded once by tool/photo_model.sh and cached by the workflow) compares
each photo with short descriptions ("a photo of a motorcycle lying on its
side on the ground", "... in good condition") and says how much of the
photo goes to each: zero-shot, no training, no tokens, no third party.
The photos come from bin/photos.dart, which already downloads them for
their fingerprints (P.1): no extra request, and they are never written to
disk.

  photo_examine.py <model_dir>
      Reads one JSON object per line on stdin ({"image": <base64 bytes>})
      and answers each with one line on stdout: {"scores": {code: share},
      "features": <base64>} or {"error": <why>}. The first line it writes
      is {"ready": <model name>}. `features` is the photo's image
      embedding (unit length, 512 signed bytes: x 127, rounded), kept so a
      classifier can later learn from Rafael's marks (P.3) without
      downloading the photo again.

The scores are hints, never part of a score; the database decides which
are shown (photo_hint_codes).
"""

import base64
import io
import json
import os
import sys

MODEL = 'clip-vit-b32'
LOGIT_SCALE = 100.0
SIZE = 224
MEAN = (0.48145466, 0.4578275, 0.40821073)
STD = (0.26862954, 0.26130258, 0.27577711)

# Each code and the descriptions that stand for it. `ok` and `other` are
# the alternatives a photo without a problem goes to (a whole bike, a
# detail, the dashboard, a document or a dealer's banner), so a hint needs
# the photo to look more like it than like all of them. Codes never change:
# the database and the app's photoHintLabel use them.
LABELS = (
    ('crashed', (
        'a photo of a crashed motorcycle with broken parts',
        'a photo of a damaged motorcycle after an accident',
    )),
    ('fallen', (
        'a photo of a motorcycle lying on its side on the ground',
    )),
    ('scratches', (
        'a close-up photo of scratches and scuffs on a motorcycle',
        'a photo of a motorcycle with scratched paint',
    )),
    ('broken_parts', (
        'a photo of a motorcycle with a broken fairing',
        'a photo of a motorcycle with a broken lever or mirror',
    )),
    ('missing_parts', (
        'a photo of a motorcycle with missing fairings and exposed parts',
    )),
    ('rust', (
        'a photo of a rusty motorcycle',
        'a close-up photo of rust and corrosion on a motorcycle',
    )),
    ('ok', (
        'a photo of a motorcycle in good condition',
        'a photo of a clean, well kept motorcycle',
        'a close-up photo of shiny, clean motorcycle paint',
        'a close-up photo of a motorcycle engine',
        'a close-up photo of a motorcycle wheel and tyre',
    )),
    ('other', (
        'a photo of a motorcycle dashboard',
        'a photo of a document or a page of text',
        'an advertising banner with a logo',
    )),
)


def prompts():
    """Every description, in order, with its code."""
    return [(code, text) for code, texts in LABELS for text in texts]


def unit(rows):
    import numpy as np
    rows = np.asarray(rows, dtype=np.float32)
    norms = np.linalg.norm(rows, axis=-1, keepdims=True)
    return rows / np.maximum(norms, 1e-12)


def scores(image_embedding, text_embeddings, codes):
    """Share of each code: softmax over every description, summed by code."""
    import numpy as np
    logits = LOGIT_SCALE * (unit(text_embeddings) @ unit(image_embedding))
    logits = logits - logits.max()
    weights = np.exp(logits)
    weights = weights / weights.sum()
    shares = {}
    for code, weight in zip(codes, weights):
        shares[code] = shares.get(code, 0.0) + float(weight)
    return {code: round(share, 3) for code, share in shares.items()}


def features(image_embedding):
    """The unit embedding as signed bytes (x 127), base64."""
    import numpy as np
    vector = unit(image_embedding)
    quantized = np.clip(np.rint(vector * 127), -127, 127).astype(np.int8)
    return base64.b64encode(quantized.tobytes()).decode('ascii')


def pixels(data):
    """CLIP's input: shortest side to 224 (bicubic), centre crop, normalised."""
    import numpy as np
    from PIL import Image
    image = Image.open(io.BytesIO(data)).convert('RGB')
    width, height = image.size
    scale = SIZE / min(width, height)
    image = image.resize(
        (max(SIZE, round(width * scale)), max(SIZE, round(height * scale))),
        Image.Resampling.BICUBIC,
    )
    left = (image.width - SIZE) // 2
    top = (image.height - SIZE) // 2
    image = image.crop((left, top, left + SIZE, top + SIZE))
    array = np.asarray(image, dtype=np.float32) / 255.0
    array = (array - np.array(MEAN, np.float32)) / np.array(STD, np.float32)
    return array.transpose(2, 0, 1)[np.newaxis]


def _output(session, outputs, wanted):
    names = [o.name for o in session.get_outputs()]
    return outputs[names.index(wanted)] if wanted in names else outputs[0]


class Examiner:
    def __init__(self, model_dir):
        import numpy as np
        import onnxruntime
        from tokenizers import Tokenizer

        options = onnxruntime.SessionOptions()
        options.log_severity_level = 3
        self.vision = onnxruntime.InferenceSession(
            os.path.join(model_dir, 'vision_model.onnx'), options,
            providers=['CPUExecutionProvider'])
        text = onnxruntime.InferenceSession(
            os.path.join(model_dir, 'text_model.onnx'), options,
            providers=['CPUExecutionProvider'])
        tokenizer = Tokenizer.from_file(os.path.join(model_dir, 'tokenizer.json'))
        text_inputs = {i.name for i in text.get_inputs()}

        self.codes = []
        embeddings = []
        # One description at a time: no padding to get wrong.
        for code, description in prompts():
            encoding = tokenizer.encode(description)
            feed = {'input_ids': np.array([encoding.ids], dtype=np.int64)}
            if 'attention_mask' in text_inputs:
                feed['attention_mask'] = np.array(
                    [encoding.attention_mask], dtype=np.int64)
            out = text.run(None, feed)
            embeddings.append(_output(text, out, 'text_embeds')[0])
            self.codes.append(code)
        self.text_embeddings = unit(embeddings)
        self.vision_input = self.vision.get_inputs()[0].name

    def examine(self, data):
        out = self.vision.run(None, {self.vision_input: pixels(data)})
        embedding = _output(self.vision, out, 'image_embeds')[0]
        return {
            'scores': scores(embedding, self.text_embeddings, self.codes),
            'features': features(embedding),
        }


def serve(examiner, lines, write):
    write({'ready': MODEL})
    for line in lines:
        if not line.strip():
            continue
        try:
            data = base64.b64decode(json.loads(line)['image'], validate=True)
            write(examiner.examine(data))
        except Exception as e:  # one bad photo never stops the others
            write({'error': f'{type(e).__name__}: {e}'})


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    examiner = Examiner(sys.argv[1])

    def write(obj):
        sys.stdout.write(json.dumps(obj) + '\n')
        sys.stdout.flush()

    serve(examiner, sys.stdin, write)


if __name__ == '__main__':
    main()
