package io.github.rafaelfaria1323.file_share;

import androidx.core.content.FileProvider;

/** Hands the shared file to the app the person picks. Its own class, so it
 *  never clashes with another plugin's FileProvider. */
public class FileShareProvider extends FileProvider {}
