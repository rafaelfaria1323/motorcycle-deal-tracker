"""Tests for photo_examine.py, on tiny ONNX models made here (the real
CLIP is downloaded only by the workflow). Skipped where the photo
dependencies (tool/photo_requirements.txt, plus onnx) aren't installed;
check.yml installs them."""

import base64
import io
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import photo_examine  # noqa: E402

try:
    import numpy as np
    import onnx
    import onnxruntime  # noqa: F401
    from onnx import TensorProto, helper
    from PIL import Image
    from tokenizers import Tokenizer, models, pre_tokenizers
    DEPS = True
except ImportError:
    DEPS = False

DIM = 4


def _vision_model(path):
    # pixel_values [1, 3, H, W] -> mean of each channel -> x W -> image_embeds
    weights = np.array([[1, 0, 0, 1], [0, 1, 0, 1], [0, 0, 1, 1]], np.float32)
    graph = helper.make_graph(
        [
            helper.make_node('ReduceMean', ['pixel_values', 'axes'], ['mean'],
                             keepdims=0),
            helper.make_node('MatMul', ['mean', 'w'], ['image_embeds']),
        ],
        'vision',
        [helper.make_tensor_value_info('pixel_values', TensorProto.FLOAT,
                                       [None, 3, None, None])],
        [helper.make_tensor_value_info('image_embeds', TensorProto.FLOAT,
                                       [None, DIM])],
        [helper.make_tensor('axes', TensorProto.INT64, [2], [2, 3]),
         helper.make_tensor('w', TensorProto.FLOAT, [3, DIM], weights.ravel())],
    )
    onnx.save(helper.make_model(graph, opset_imports=[helper.make_opsetid('', 18)], ir_version=9),
              path)


def _text_model(path, vocabulary):
    # input_ids [1, n] -> rows of a table -> their mean -> text_embeds
    rng = np.random.default_rng(7)
    table = rng.normal(size=(vocabulary, DIM)).astype(np.float32)
    graph = helper.make_graph(
        [
            helper.make_node('Gather', ['table', 'input_ids'], ['rows'], axis=0),
            helper.make_node('ReduceMean', ['rows', 'axes'], ['text_embeds'],
                             keepdims=0),
        ],
        'text',
        [helper.make_tensor_value_info('input_ids', TensorProto.INT64, [1, None]),
         helper.make_tensor_value_info('attention_mask', TensorProto.INT64,
                                       [1, None])],
        [helper.make_tensor_value_info('text_embeds', TensorProto.FLOAT,
                                       [1, DIM])],
        [helper.make_tensor('table', TensorProto.FLOAT, [vocabulary, DIM],
                            table.ravel()),
         helper.make_tensor('axes', TensorProto.INT64, [1], [1])],
    )
    onnx.save(helper.make_model(graph, opset_imports=[helper.make_opsetid('', 18)], ir_version=9),
              path)


def _model_dir():
    folder = tempfile.mkdtemp()
    words = sorted({w for _, text in photo_examine.prompts()
                    for w in text.replace(',', ' ').split()})
    vocab = {'[UNK]': 0, **{w: i + 1 for i, w in enumerate(words)}}
    tokenizer = Tokenizer(models.WordLevel(vocab, unk_token='[UNK]'))
    tokenizer.pre_tokenizer = pre_tokenizers.Whitespace()
    tokenizer.save(os.path.join(folder, 'tokenizer.json'))
    _vision_model(os.path.join(folder, 'vision_model.onnx'))
    _text_model(os.path.join(folder, 'text_model.onnx'), len(vocab))
    return folder


def _jpeg(width, height, colour):
    out = io.BytesIO()
    Image.new('RGB', (width, height), colour).save(out, 'JPEG')
    return out.getvalue()


class LabelsTest(unittest.TestCase):
    def test_codes_are_unique_and_the_alternatives_are_there(self):
        codes = [code for code, _ in photo_examine.LABELS]
        self.assertEqual(len(codes), len(set(codes)))
        self.assertIn('ok', codes)
        self.assertIn('other', codes)
        self.assertEqual(
            len(photo_examine.prompts()),
            sum(len(texts) for _, texts in photo_examine.LABELS))


@unittest.skipUnless(DEPS, 'photo dependencies not installed')
class MathTest(unittest.TestCase):
    def test_scores_share_everything_and_sum_by_code(self):
        texts = np.array([[1, 0], [0, 1], [0, 1]], np.float32)
        shares = photo_examine.scores(
            np.array([0, 2], np.float32), texts, ['a', 'b', 'b'])
        self.assertAlmostEqual(sum(shares.values()), 1, places=2)
        self.assertGreater(shares['b'], 0.99)
        # Two descriptions as close as one: twice the share.
        even = photo_examine.scores(
            np.array([1, 1], np.float32), texts, ['a', 'b', 'c'])
        self.assertAlmostEqual(even['a'], 1 / 3, places=2)

    def test_features_are_the_unit_vector_in_signed_bytes(self):
        raw = base64.b64decode(photo_examine.features(np.array([3, -4], np.float32)))
        self.assertEqual(list(np.frombuffer(raw, np.int8)), [76, -102])

    def test_pixels_crop_the_middle_square_and_normalise(self):
        # Wide: the left and right thirds are cut off.
        image = Image.new('RGB', (672, 224), (0, 0, 0))
        image.paste((255, 255, 255), (224, 0, 448, 224))
        out = io.BytesIO()
        image.save(out, 'PNG')
        array = photo_examine.pixels(out.getvalue())
        self.assertEqual(array.shape, (1, 3, 224, 224))
        white = (1 - photo_examine.MEAN[0]) / photo_examine.STD[0]
        self.assertAlmostEqual(float(array[0, 0].min()), white, places=3)
        self.assertEqual(array.dtype, np.float32)


@unittest.skipUnless(DEPS, 'photo dependencies not installed')
class ServeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.examiner = photo_examine.Examiner(_model_dir())

    def _serve(self, lines):
        written = []
        photo_examine.serve(self.examiner, lines, written.append)
        return written

    def test_ready_first_then_one_answer_per_photo(self):
        photo = base64.b64encode(_jpeg(400, 300, (200, 30, 30))).decode()
        written = self._serve([json.dumps({'image': photo}), '\n'])
        self.assertEqual(written[0], {'ready': photo_examine.MODEL})
        self.assertEqual(len(written), 2)
        answer = written[1]
        self.assertEqual(set(answer['scores']),
                         {code for code, _ in photo_examine.LABELS})
        self.assertAlmostEqual(sum(answer['scores'].values()), 1, places=2)
        self.assertEqual(len(base64.b64decode(answer['features'])), DIM)

    def test_a_bad_photo_is_an_error_and_the_next_still_answers(self):
        good = base64.b64encode(_jpeg(64, 64, (10, 10, 10))).decode()
        written = self._serve([
            json.dumps({'image': base64.b64encode(b'not an image').decode()}),
            'not json',
            json.dumps({'image': good}),
        ])
        self.assertIn('error', written[1])
        self.assertIn('error', written[2])
        self.assertIn('scores', written[3])

    def test_the_same_photo_gives_the_same_answer(self):
        photo = base64.b64encode(_jpeg(300, 300, (0, 90, 200))).decode()
        line = json.dumps({'image': photo})
        written = self._serve([line, line])
        self.assertEqual(written[1], written[2])


if __name__ == '__main__':
    unittest.main()
