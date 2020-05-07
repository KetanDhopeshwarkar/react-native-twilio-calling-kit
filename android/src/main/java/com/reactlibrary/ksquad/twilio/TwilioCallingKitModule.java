package com.reactlibrary.ksquad.twilio;

import android.content.Intent;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;

public class TwilioCallingKitModule extends ReactContextBaseJavaModule {

    @SuppressWarnings("WeakerAccess")
    protected static ReactApplicationContext reactContext;

    @SuppressWarnings("WeakerAccess")
    public TwilioCallingKitModule(ReactApplicationContext reactContext) {
        super(reactContext);
        TwilioCallingKitModule.reactContext = reactContext;
    }

    @NonNull
    @Override
    public String getName() {
        return "TwilioCallingKit";
    }

    @SuppressWarnings("unused")
    @ReactMethod
    public void connect(final ReadableMap props) {
        Intent intent = new Intent(getCurrentActivity(), VideoCallingActivity.class);
        intent.putExtra("token", props.getString("token"));
        intent.putExtra("room_name", props.getString("room_name"));
        intent.putExtra("header", props.getString("header"));
        intent.putExtra("sub_header", props.getString("sub_header"));
        intent.putExtra("is_voice_call", props.getBoolean("is_voice_call"));
        //noinspection ConstantConditions
        getCurrentActivity().startActivity(intent);
    }
}
