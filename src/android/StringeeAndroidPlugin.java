package com.stringee.cordova;

import android.Manifest;
import android.content.pm.PackageManager;
import android.view.ViewGroup;

import com.stringee.StringeeClient;
import com.stringee.call.StringeeCall;
import com.stringee.exception.StringeeError;
import com.stringee.listener.StringeeConnectionListener;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;

public class StringeeAndroidPlugin extends CordovaPlugin implements StringeeConnectionListener, StringeeCall.StringeeCallListener {

    private StringeeClient mClient;
    private HashMap<String, StringeeCall> callMap;


    private HashMap<String, CallbackContext> myEventListeners;
    private HashMap<String, CallbackContext> makeCallListeners;
    private static final String[] permsVoiceCall = {Manifest.permission.RECORD_AUDIO};
    private static final String[] permsVideoCall = {Manifest.permission.RECORD_AUDIO, Manifest.permission.CAMERA};
    private CallbackContext permissionsCallback;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        myEventListeners = new HashMap<>();
        callMap = new HashMap<>();
        makeCallListeners = new HashMap<>();

        super.initialize(cordova, webView);
    }

    @Override
    public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
        if (action.equals("initStringeeClient")) {
            mClient = new StringeeClient(this.cordova.getActivity());
            mClient.setConnectionListener(this);
            callbackContext.success();
        } else if (action.equals("connect")) {
            mClient.connect(args.getString(0));
        } else if (action.equals("disconnect")) {
            if (mClient == null) {
                callbackContext.error("StringeeClient is not initialized.");
                return true;
            }
            mClient.disconnect();
            return true;
        } else if (action.equals("initStringeeCall")) {
            if (mClient == null) {
                callbackContext.error("StringeeClient is not initialized.");
                return true;
            }
            StringeeCall mCall = new StringeeCall(this.cordova.getActivity(), mClient, args.getString(1), args.getString(2));
            mCall.setCustomId(args.getString(0));
            mCall.setCallListener(this);
            mCall.setVideoCall(args.getBoolean(3));
            String customData = args.getString(5);
            if (customData != null && customData.length() > 0) {
                mCall.setCustom(customData);
            }
            callMap.put(mCall.getCustomId(), mCall);
            callbackContext.success();
        } else if (action.equals("makeCall")) {
            if (mClient == null) {
                callbackContext.error("StringeeClient is not initialized.");
                return true;
            }
            StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall == null) {
                callbackContext.error("StringeeCall not found.");
                return true;
            }
            makeCallListeners.put(mCall.getCustomId(), callbackContext);
            mCall.makeCall();
        } else if (action.equals("initAnswer")) {
            if (mClient == null) {
                callbackContext.error("StringeeClient is not initialized.");
                return true;
            }
            StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall == null) {
                callbackContext.error("StringeeCall not found.");
                return true;
            }

            mCall.initAnswer(cordova.getActivity(), mClient);
        } else if (action.equals("addEvent")) {
            myEventListeners.put(args.getString(0), callbackContext);
        } else if (action.equals("hangup")) {
            if (mClient == null) {
                callbackContext.error("StringeeClient is not initialized.");
                return true;
            }
            StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall == null) {
                callbackContext.error("StringeeCall not found.");
                return true;
            }
            mCall.hangup();
        } else if (action.equals("answer")) {
            if (mClient == null) {
                callbackContext.error("StringeeClient is not initialized.");
                return true;
            }
            StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall == null) {
                callbackContext.error("StringeeCall not found.");
                return true;
            }
            mCall.answer();
        } else if (action.equals("reject")) {
            if (mClient == null) {
                callbackContext.error("StringeeClient is not initialized.");
                return true;
            }
            StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall == null) {
                callbackContext.error("StringeeCall not found.");
                return true;
            }
            mCall.reject();
        } else if (action.equals("mute")) {
            StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall != null) {
                mCall.mute(args.getBoolean(1));
            }
        } else if (action.equals("setSpeakerphoneOn")) {
            StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall != null) {
                mCall.setSpeakerphoneOn(args.getBoolean(1));
            }
        } else if (action.equals("switchCamera")) {
            StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall != null) {
                mCall.switchCamera(null);
            }
        } else if (action.equals("enableVideo")) {
            StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall != null) {
                mCall.enableVideo(args.getBoolean(1));
            }
        } else if (action.equals("requestPermissions")) {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                if (args.getBoolean(0)) {
                    if (cordova.hasPermission(Manifest.permission.RECORD_AUDIO) && cordova.hasPermission(Manifest.permission.CAMERA)) {
                        callbackContext.success();
                        return true;
                    }
                    cordova.requestPermissions(this, 0, permsVideoCall);
                } else {
                    if (cordova.hasPermission(Manifest.permission.RECORD_AUDIO)) {
                        callbackContext.success();
                        return true;
                    }
                    cordova.requestPermissions(this, 0, permsVoiceCall);
                }
                permissionsCallback = callbackContext;
            } else {
                callbackContext.success();
            }
        } else if (action.equals("sendDTMF")) {
            if (mClient == null) {
                callbackContext.error("StringeeClient is not initialized.");
                return true;
            }
            StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall == null) {
                callbackContext.error("StringeeCall not found.");
                return true;
            }
            mCall.sendDTMF(args.getString(1));
        } else if (action.equals("renderVideo")) {
            final StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall == null) {
                callbackContext.error("StringeeCall not found.");
                return true;
            }
            boolean isLocal = args.getBoolean(1);
            if (isLocal) {
                cordova.getActivity().runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        ((ViewGroup) webView.getView().getParent()).addView(mCall.getLocalView());
                        mCall.renderLocalView(false);
                    }
                });
            } else {
                cordova.getActivity().runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        ((ViewGroup) webView.getView().getParent()).addView(mCall.getRemoteView());
                        mCall.renderRemoteView(true);
                    }
                });
            }
        } else if (action.equals("registerPush")) {
            if (mClient == null) {
                callbackContext.error("StringeeClient is not initialized.");
                return true;
            }
            mClient.registerPushToken(args.getString(0), new StringeeClient.RegisterPushTokenListener() {
                @Override
                public void onPushTokenRegistered(boolean b, String s) {
                    if (b) {
                        callbackContext.success();
                    } else {
                        callbackContext.error(s);
                    }
                }

                @Override
                public void onPushTokenUnRegistered(boolean b, String s) {

                }
            });
        } else if (action.equals("unregisterPush")) {
            if (mClient == null) {
                callbackContext.error("StringeeClient is not initialized.");
                return true;
            }
            mClient.unregisterPushToken(args.getString(0), new StringeeClient.RegisterPushTokenListener() {
                @Override
                public void onPushTokenRegistered(boolean b, String s) {
                    if (b) {
                        callbackContext.success();
                    } else {
                        callbackContext.error(s);
                    }
                }

                @Override
                public void onPushTokenUnRegistered(boolean b, String s) {

                }
            });
        } else if (action.equals("sendCallInfo")) {
            StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall == null) {
                callbackContext.error("StringeeCall not found.");
                return true;
            }
            JSONObject jsonObject = new JSONObject(args.getString(1));
            mCall.sendCallInfo(jsonObject);
            callbackContext.success();
        } else if (action.equals("getCallStats")) {
            StringeeCall mCall = callMap.get(args.getString(0));
            if (mCall == null) {
                callbackContext.error("StringeeCall not found.");
                return true;
            }
            mCall.getStats(new StringeeCall.CallStatsListener() {
                @Override
                public void onCallStats(StringeeCall.StringeeCallStats stringeeCallStats) {
                    JSONObject message = new JSONObject();

                    try {
                        message.put("bytesReceived", stringeeCallStats.callBytesReceived);
                        message.put("packetsLost", stringeeCallStats.callPacketsLost);
                        message.put("packetsReceived", stringeeCallStats.callPacketsReceived);
                        message.put("timeStamp", stringeeCallStats.timeStamp);
                    } catch (JSONException e) {
                    }

                    PluginResult myResult = new PluginResult(PluginResult.Status.OK, message);
                    myResult.setKeepCallback(true);
                    callbackContext.sendPluginResult(myResult);
                }
            });
        }
        return true;
    }

    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] results) throws JSONException {
        Boolean permissionError = false;
        for (int permissionResult : results) {
            if (permissionResult == PackageManager.PERMISSION_DENIED) {
                permissionError = true;
            }
        }
        if (permissionError) {
            permissionsCallback.error("Permissions denied.");
        } else {
            switch (requestCode) {
                case 0:
                    permissionsCallback.success();
                    break;
            }
        }
    }

    public void triggerJSEvent(String event, String type, Object data) {
        JSONObject message = new JSONObject();

        try {
            message.put("eventType", type);
            message.put("data", data);
        } catch (JSONException e) {
        }

        PluginResult myResult = new PluginResult(PluginResult.Status.OK, message);
        myResult.setKeepCallback(true);
        myEventListeners.get(event).sendPluginResult(myResult);
    }

    @Override
    public void onConnectionConnected(StringeeClient stringeeClient, boolean isReconnecting) {
        JSONObject data = new JSONObject();
        try {
            data.put("userId", stringeeClient.getUserId());
            data.put("projectId", stringeeClient.getProjectId());
            data.put("isReconnecting", isReconnecting);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        triggerJSEvent("clientEvents", "didConnect", data);
    }

    @Override
    public void onConnectionDisconnected(StringeeClient stringeeClient, boolean isReconnecting) {
        JSONObject data = new JSONObject();
        try {
            data.put("userId", stringeeClient.getUserId());
            data.put("projectId", stringeeClient.getProjectId());
            data.put("isReconnecting", isReconnecting);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        triggerJSEvent("clientEvents", "didDisConnect", data);
    }

    @Override
    public void onIncomingCall(StringeeCall stringeeCall) {
        stringeeCall.setCustomId(stringeeCall.getCallId());
        callMap.put(stringeeCall.getCallId(), stringeeCall);
        JSONObject data = new JSONObject();
        try {
            data.put("callId", stringeeCall.getCallId());
            data.put("from", stringeeCall.getFrom());
            data.put("to", stringeeCall.getTo());
            data.put("fromAlias", stringeeCall.getFromAlias());
            data.put("toAlias", stringeeCall.getToAlias());
            data.put("customDataFromYourServer", stringeeCall.getCustomDataFromYourServer());
            int callType = 1;
            if (stringeeCall.isPhoneToAppCall()) {
                callType = 3;
            }
            data.put("callType", callType);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        triggerJSEvent("clientEvents", "incomingCall", data);
    }

    @Override
    public void onConnectionError(StringeeClient stringeeClient, StringeeError stringeeError) {
        JSONObject data = new JSONObject();
        try {
            data.put("userId", stringeeClient.getUserId());
            data.put("code", stringeeError.getCode());
            data.put("message", stringeeError.getMessage());
        } catch (JSONException e) {
            e.printStackTrace();
        }
        triggerJSEvent("clientEvents", "didFailWithError", data);
    }

    @Override
    public void onRequestNewToken(StringeeClient stringeeClient) {
        JSONObject data = new JSONObject();
        try {
            data.put("userId", stringeeClient.getUserId());
        } catch (JSONException e) {
            e.printStackTrace();
        }
        triggerJSEvent("clientEvents", "requestAccessToken", data);
    }

    @Override
    public void onSignalingStateChange(StringeeCall stringeeCall, StringeeCall.SignalingState signalingState, String s, int i, String s1) {
        if (signalingState == StringeeCall.SignalingState.CALLING) {
            int callType = 0;
            if (stringeeCall.isAppToPhoneCall()) {
                callType = 2;
            }

            JSONObject data = new JSONObject();
            try {
                data.put("callId", stringeeCall.getCallId());
                data.put("from", stringeeCall.getFrom());
                data.put("to", stringeeCall.getTo());
                data.put("fromAlias", stringeeCall.getFromAlias());
                data.put("toAlias", stringeeCall.getToAlias());
                data.put("customDataFromYourServer", stringeeCall.getCustomDataFromYourServer());
                data.put("callType", callType);
            } catch (JSONException e) {
                e.printStackTrace();
            }

            JSONObject message = new JSONObject();
            try {
                message.put("data", data);
            } catch (JSONException e) {
            }

            PluginResult myResult = new PluginResult(PluginResult.Status.OK, message);
            myResult.setKeepCallback(true);
            makeCallListeners.get(stringeeCall.getCustomId()).sendPluginResult(myResult);
        }


        JSONObject data = new JSONObject();
        try {
            data.put("callId", stringeeCall.getCallId());
            data.put("code", signalingState.getValue());
            data.put("reason", s);
            data.put("sipCode", i);
            data.put("sipReason", s1);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        triggerJSEvent(stringeeCall.getCustomId(), "didChangeSignalingState", data);
    }

    @Override
    public void onError(StringeeCall stringeeCall, int i, String s) {
        JSONObject data = new JSONObject();
        try {
            data.put("callId", stringeeCall.getCallId());
            data.put("code", i);
            data.put("message", s);
        } catch (JSONException e) {
            e.printStackTrace();
        }

        JSONObject message = new JSONObject();
        try {
            message.put("data", data);
        } catch (JSONException e) {
        }

        PluginResult myResult = new PluginResult(PluginResult.Status.ERROR, message);
        myResult.setKeepCallback(false);
        makeCallListeners.get(stringeeCall.getCustomId()).sendPluginResult(myResult);
    }

    @Override
    public void onHandledOnAnotherDevice(StringeeCall stringeeCall, StringeeCall.SignalingState signalingState, String s) {
        JSONObject data = new JSONObject();
        try {
            data.put("callId", stringeeCall.getCallId());
            data.put("code", signalingState.getValue());
            data.put("description", s);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        triggerJSEvent(stringeeCall.getCallId(), "didHandleOnAnotherDevice", data);
    }

    @Override
    public void onMediaStateChange(StringeeCall stringeeCall, StringeeCall.MediaState mediaState) {
        JSONObject data = new JSONObject();
        try {
            data.put("callId", stringeeCall.getCallId());
            data.put("code", mediaState.getValue());
            data.put("description", mediaState.toString());
        } catch (JSONException e) {
            e.printStackTrace();
        }
        triggerJSEvent(stringeeCall.getCustomId(), "didChangeMediaState", data);
    }

    @Override
    public void onLocalStream(StringeeCall stringeeCall) {
        JSONObject data = new JSONObject();
        try {
            data.put("callId", stringeeCall.getCallId());
        } catch (JSONException e) {
            e.printStackTrace();
        }
        triggerJSEvent(stringeeCall.getCustomId(), "didReceiveLocalStream", data);
    }

    @Override
    public void onRemoteStream(StringeeCall stringeeCall) {
        JSONObject data = new JSONObject();
        try {
            data.put("callId", stringeeCall.getCallId());
        } catch (JSONException e) {
            e.printStackTrace();
        }
        triggerJSEvent(stringeeCall.getCustomId(), "didReceiveRemoteStream", data);
    }

    @Override
    public void onCallInfo(StringeeCall stringeeCall, JSONObject jsonObject) {
        JSONObject data = new JSONObject();
        try {
            data.put("callId", stringeeCall.getCallId());
            data.put("data", jsonObject);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        triggerJSEvent(stringeeCall.getCustomId(), "didReceiveCallInfo", data);
    }
}