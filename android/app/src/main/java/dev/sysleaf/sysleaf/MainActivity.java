package dev.sysleaf.sysleaf;

import android.content.Context;
import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;

/** Android entry point: only passes an Application context to the Rust core. */
public class MainActivity extends FlutterActivity {
    static { System.loadLibrary("sysleaf_core"); }
    private static native void nativeInitialize(Context context);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        nativeInitialize(getApplicationContext());
        super.onCreate(savedInstanceState);
    }
}
