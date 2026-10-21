package io.github.rafaelfaria1323.apk_installer;

import androidx.core.content.FileProvider;

/** Shares the downloaded APK with Android's installer. Its own class, so it
 *  never clashes with another plugin's FileProvider. */
public class ApkFileProvider extends FileProvider {}
