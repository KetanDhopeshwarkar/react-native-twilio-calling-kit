package com.reactlibrary;

import android.app.Activity;
import android.content.Intent;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.BaseActivityEventListener;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;

public class TwilioCallingKitModule extends ReactContextBaseJavaModule {

    protected static ReactApplicationContext reactContext;

    public TwilioCallingKitModule(ReactApplicationContext reactContext) {
        super(reactContext);
        TwilioCallingKitModule.reactContext = reactContext;
        ActivityEventListener mActivityEventListener = new BaseActivityEventListener() {

            @Override
            public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent intent) {

            }
        };
        reactContext.addActivityEventListener(mActivityEventListener);
    }

    @NonNull
    @Override
    public String getName() {
        return "TwilioCallingKit";
    }

    @ReactMethod
    public void connect(final ReadableMap props, final Callback success, final Callback error) {
        Intent intent = new Intent(getCurrentActivity(), VideoCallingActivity.class);
        intent.putExtra("token", props.getString("token"));
        intent.putExtra("room_name", props.getString("room_name"));
        intent.putExtra("header", props.getString("header"));
        intent.putExtra("sub_header", props.getString("sub_header"));
        intent.putExtra("is_voice_call", props.getBoolean("is_voice_call"));
        //noinspection ConstantConditions
        getCurrentActivity().startActivityForResult(intent, 118);
    }
}
