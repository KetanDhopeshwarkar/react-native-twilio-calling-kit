package com.reactlibrary.ksquad.twilio;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;
import android.view.View;
import android.view.animation.TranslateAnimation;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.google.android.material.snackbar.Snackbar;
import com.twilio.video.CameraCapturer;
import com.twilio.video.CameraCapturer.CameraSource;
import com.twilio.video.ConnectOptions;
import com.twilio.video.LocalAudioTrack;
import com.twilio.video.LocalParticipant;
import com.twilio.video.LocalVideoTrack;
import com.twilio.video.RemoteAudioTrack;
import com.twilio.video.RemoteAudioTrackPublication;
import com.twilio.video.RemoteDataTrack;
import com.twilio.video.RemoteDataTrackPublication;
import com.twilio.video.RemoteParticipant;
import com.twilio.video.RemoteVideoTrack;
import com.twilio.video.RemoteVideoTrackPublication;
import com.twilio.video.Room;
import com.twilio.video.TwilioException;
import com.twilio.video.Video;
import com.twilio.video.VideoRenderer;
import com.twilio.video.VideoTrack;
import com.twilio.video.VideoView;

import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Collections;
import java.util.TimeZone;


/*
 * This Activity shows how to use Twilio Video with Twilio Notify to invite other participants
 * that have registered with Twilio Notify via push notifications.
 */
public class VideoCallingActivity extends AppCompatActivity {
    private static final int CAMERA_MIC_PERMISSION_REQUEST_CODE = 1;

    /*
     * Intent keys used to provide information about a video notification
     */
//    public static final String ACTION_VIDEO_NOTIFICATION = "VIDEO_NOTIFICATION";
//    public static final String VIDEO_NOTIFICATION_ROOM_NAME = "VIDEO_NOTIFICATION_ROOM_NAME";
//    public static final String VIDEO_NOTIFICATION_TITLE = "VIDEO_NOTIFICATION_TITLE";

    /*
     * Intent keys used to obtain a token and register with Twilio Notify
     */
//    public static final String ACTION_REGISTRATION = "ACTION_REGISTRATION";
//    public static final String REGISTRATION_ERROR = "REGISTRATION_ERROR";
//    public static final String REGISTRATION_IDENTITY = "REGISTRATION_IDENTITY";
//    public static final String REGISTRATION_TOKEN = "REGISTRATION_TOKEN";

    /*
     * Token obtained from the sdk-starter /token resource
     */
    //private String token;

    /*
     * Identity obtained from the sdk-starter /token resource
     */
//    @SuppressWarnings("FieldCanBeLocal")
//    private String identity;

    /*
     * A Room represents communication between a local participant and one or more participants.
     */
    private Room room;

    /*
     * A LocalParticipant represents the identity and tracks provided by this instance
     */
    private LocalParticipant localParticipant;

    /*
     * A VideoView receives frames from a local or remote video track and renders them
     * to an associated view.
     */
    private VideoView primaryVideoView;
    private VideoView thumbnailVideoView;

//    private boolean isReceiverRegistered;
//    private LocalBroadcastReceiver localBroadcastReceiver;
//    private NotificationManager notificationManager;
//    private Intent cachedVideoNotificationIntent;

    /*
     * Android application UI elements
     */
    private TextView statusTextView;
    private TextView timerText;
    private CameraCapturer cameraCapturer;
    private LocalAudioTrack localAudioTrack;
    private LocalVideoTrack localVideoTrack;
    private ImageView connectActionFab;
    private ImageView backButton;
    private ImageView switchCameraActionFab;
    private ImageView localVideoActionFab;
    private ImageView muteActionFab;
    private ProgressBar reconnectingProgressBar;
    //    private AlertDialog alertDialog;
    private AudioManager audioManager;
    private String remoteParticipantIdentity;
    //    private ImageView turnSpeakerOnMenuItem;
//    private ImageView turnSpeakerOffMenuItem;
//    private ImageView dummyMenuVoiceCall;
    private ImageView turnSpeakerOff;
    private ImageView turnSpeakerOn;

    private int previousAudioMode;
    private VideoRenderer localVideoView;
    private boolean disconnectedFromOnDestroy;
    private final static String TAG = "VideoCallingActivity";
    private String token;
    private String roomName;
    private boolean isUp;
    private LinearLayout headerLayout;
    private LinearLayout animatedHeaderView;
    private LinearLayout buttonLayout;
    private RelativeLayout actionButtonLayout;
    private boolean isVoiceCall = false;
    private ImageView backgroundView;
    private View voiceBackgroundView;
    private long time;
    private boolean isTimerStart = false;
    @SuppressLint("SimpleDateFormat")
    private SimpleDateFormat df = new SimpleDateFormat("HH:mm:ss");

    @SuppressLint("SetTextI18n")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_video);

        primaryVideoView = findViewById(R.id.primary_video_view);
        thumbnailVideoView = findViewById(R.id.thumbnail_video_view);
        statusTextView = findViewById(R.id.status_textview);
        TextView headerText = findViewById(R.id.header_text);
        TextView subHeaderText = findViewById(R.id.sub_header_text);
        animatedHeaderView = findViewById(R.id.animated_header_view);
        headerLayout = findViewById(R.id.header_layout);
        buttonLayout = findViewById(R.id.button_layout);
        actionButtonLayout = findViewById(R.id.action_button_layout);
        timerText = findViewById(R.id.timer_text);

        connectActionFab = findViewById(R.id.connect_action_fab);
        backButton = findViewById(R.id.back_button);
        switchCameraActionFab = findViewById(R.id.switch_camera_action_fab);
        localVideoActionFab = findViewById(R.id.local_video_action_fab);
        muteActionFab = findViewById(R.id.mute_action_fab);
//        turnSpeakerOnMenuItem = findViewById(R.id.menu_turn_speaker_on);
//        turnSpeakerOffMenuItem = findViewById(R.id.menu_turn_speaker_off);
//        dummyMenuVoiceCall = findViewById(R.id.dummy_menu_voice_call);
        turnSpeakerOn = findViewById(R.id.turn_speaker_on);
        turnSpeakerOff = findViewById(R.id.turn_speaker_off);
        reconnectingProgressBar = findViewById(R.id.reconnecting_progress_bar);
        backgroundView = findViewById(R.id.background_view);
        voiceBackgroundView = findViewById(R.id.voice_background_view);

        /*
         * Hide the connect button until we successfully register with Twilio Notify
         */
        //connectActionFab.setVisibility(View.GONE);

        /*
         * Enable changing the volume using the up/down keys during a conversation
         */
        setVolumeControlStream(AudioManager.STREAM_VOICE_CALL);

        /*
         * Needed for setting/abandoning audio focus during call
         */
        audioManager = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        audioManager.setSpeakerphoneOn(true);

        /*
         * Setup the broadcast receiver to be notified of video notification messages
         */
        //localBroadcastReceiver = new LocalBroadcastReceiver();
        //registerReceiver();

//        notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

        Intent intent = getIntent();
        if (intent.getExtras() != null) {
            token = intent.getStringExtra("token");
            roomName = intent.getStringExtra("room_name");
            String header = intent.getStringExtra("header");
            String subHeader = intent.getStringExtra("sub_header");
            isVoiceCall = intent.getBooleanExtra("is_voice_call", false);
            headerText.setText("" + header);
            subHeaderText.setText("" + subHeader);
        }

        df.setTimeZone(TimeZone.getTimeZone("GMT"));

        if (!isVoiceCall) {
            new Handler().postDelayed(() -> {
                slideDown(headerLayout, false);
                slideDown(buttonLayout, true);
                backgroundView.setOnClickListener(this::onSlideViewButtonClick);
            }, 10000);
        } else {
            renderVoiceCallUI();
        }
        /*
         * Check camera and microphone permissions. Needed in Android M.
         */
        if (!checkPermissionForCameraAndMicrophone()) {
            requestPermissionForCameraAndMicrophone();
//        } else if (intent != null && intent.getAction() != null && intent.getAction().equals(ACTION_REGISTRATION)) {
//            handleRegistration(intent);
//        } else if (intent != null && intent.getAction() != null && intent.getAction().equals(ACTION_VIDEO_NOTIFICATION)) {
//            /*
//             * Cache the video invite notification intent until an access token is obtained through
//             * registration
//             */
//            cachedVideoNotificationIntent = intent;
//            register();
        } else {
//            register();
            connectToRoom();
        }
    }

    private void startTimer() {
        new Handler().postDelayed(() -> {
            if (isTimerStart) {
                time = time + 1000;
                startTimer();
                String s = df.format(time);
                timerText.setText(s);
            }
        }, 1000);
    }

    private void renderVoiceCallUI() {
        headerLayout.setBackground(ContextCompat.getDrawable(this, R.drawable.shape_voice_call_background_drawable));
        actionButtonLayout.setBackground(ContextCompat.getDrawable(this, R.drawable.shape_voice_call_action_btn_background_drawable));
        localVideoActionFab.setImageDrawable(ContextCompat.getDrawable(this, R.drawable.ic_videocam_off));
        switchCameraActionFab.setVisibility(View.GONE);
//        turnSpeakerOnMenuItem.setVisibility(View.GONE);
//        turnSpeakerOffMenuItem.setVisibility(View.GONE);
//        dummyMenuVoiceCall.setVisibility(View.INVISIBLE);
        turnSpeakerOff.setVisibility(View.VISIBLE);
        turnSpeakerOn.setVisibility(View.GONE);
        voiceBackgroundView.setVisibility(View.VISIBLE);
        backgroundView.setVisibility(View.GONE);
        primaryVideoView.setVisibility(View.INVISIBLE);
    }

    private void renderVideoCallUI() {
        if (isVoiceCall) {
            isVoiceCall = false;
            headerLayout.setBackground(null);
            actionButtonLayout.setBackground(null);

            audioManager.setSpeakerphoneOn(true);
            /*if (turnSpeakerOn.getVisibility() == View.VISIBLE) {
                turnSpeakerOnMenuItem.setVisibility(View.VISIBLE);
                turnSpeakerOffMenuItem.setVisibility(View.GONE);
            } else {
                turnSpeakerOnMenuItem.setVisibility(View.GONE);
                turnSpeakerOffMenuItem.setVisibility(View.VISIBLE);
            }
            dummyMenuVoiceCall.setVisibility(View.GONE);*/
            turnSpeakerOff.setVisibility(View.GONE);
            turnSpeakerOn.setVisibility(View.GONE);
            voiceBackgroundView.setVisibility(View.GONE);
            backgroundView.setVisibility(View.VISIBLE);
            new Handler().postDelayed(() -> {
                slideDown(headerLayout, false);
                slideDown(buttonLayout, true);
                backgroundView.setOnClickListener(this::onSlideViewButtonClick);
            }, 10000);
            primaryVideoView.setVisibility(View.VISIBLE);
            if (room != null && !room.getRemoteParticipants().isEmpty()) {
                thumbnailVideoView.setVisibility(View.VISIBLE);
            }
        }
    }

    // slide the view from its current position to below itself
    public void slideDown(View view, boolean isBottomView) {
        try {
            TranslateAnimation animate = new TranslateAnimation(
                    0,                 // fromXDelta
                    0,                 // toXDelta
                    0,                 // fromYDelta
                    isBottomView ? view.getHeight() : -1 * animatedHeaderView.getHeight()); // toYDelta
            animate.setDuration(500);
            animate.setFillAfter(true);
            view.startAnimation(animate);
            if (isBottomView) {
                new Handler().postDelayed(() -> buttonLayout.setVisibility(View.GONE), 500);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // slide the view from below itself to the current position
    public void slideUp(View view, boolean isBottomView) {
        view.setVisibility(View.VISIBLE);
        TranslateAnimation animate = new TranslateAnimation(
                0,                 // fromXDelta
                0,                 // toXDelta
                isBottomView ? view.getHeight() : -1 * animatedHeaderView.getHeight(),  // fromYDelta
                0);                // toYDelta
        animate.setDuration(500);
        animate.setFillAfter(true);
        view.startAnimation(animate);
    }

    public void onSlideViewButtonClick(View view) {
        if (isUp) {
            slideDown(headerLayout, false);
            slideDown(buttonLayout, true);
        } else {
            slideUp(headerLayout, false);
            slideUp(buttonLayout, true);
        }
        isUp = !isUp;
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
                                           @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        if (requestCode == CAMERA_MIC_PERMISSION_REQUEST_CODE) {
            boolean cameraAndMicPermissionGranted = true;

            for (int grantResult : grantResults) {
                cameraAndMicPermissionGranted &= grantResult == PackageManager.PERMISSION_GRANTED;
            }

            if (cameraAndMicPermissionGranted) {
//                register();
                connectToRoom();
            } else {
                Log.e(TAG, getString(R.string.permissions_needed));
                Toast.makeText(this,
                        R.string.permissions_needed,
                        Toast.LENGTH_LONG).show();
            }
        }
    }

    /*
     * Register to obtain a token and register a binding with Twilio Notify
     */
//    private void register() {
//        Intent intent = new Intent(this, RegistrationIntentService.class);
//        startService(intent);
//    }

    /*
     * Called when a notification is clicked and this activity is in the background or closed
     */
//    @Override
//    protected void onNewIntent(final Intent intent) {
//        super.onNewIntent(intent);
//        if (intent.getAction() != null && intent.getAction().equals(ACTION_VIDEO_NOTIFICATION)) {
//            handleVideoNotificationIntent(intent);
//        }
//    }

//    private void handleRegistration(Intent intent) {
//        String registrationError = intent.getStringExtra(REGISTRATION_ERROR);
//        if (registrationError != null) {
//            statusTextView.setText(registrationError);
//        } else {
//            createLocalTracks();
//            identity = intent.getStringExtra(REGISTRATION_IDENTITY);
//            token = intent.getStringExtra(REGISTRATION_TOKEN);
//            statusTextView.setText(R.string.registered);
//            intializeUI();
//            if (cachedVideoNotificationIntent != null) {
//                handleVideoNotificationIntent(cachedVideoNotificationIntent);
//                cachedVideoNotificationIntent = null;
//            }
//        }
//    }

//    private void handleVideoNotificationIntent(Intent intent) {
//        notificationManager.cancelAll();
//        /*
//         * Only handle the notification if not already connected to a Video Room
//         */
//        if (room == null) {
//            String title = intent.getStringExtra(VIDEO_NOTIFICATION_TITLE);
//            String dialogRoomName = intent.getStringExtra(VIDEO_NOTIFICATION_ROOM_NAME);
//            showVideoNotificationConnectDialog(title, dialogRoomName);
//        }
//    }

//    private void registerReceiver() {
//        if (!isReceiverRegistered) {
//            IntentFilter intentFilter = new IntentFilter();
//            intentFilter.addAction(ACTION_VIDEO_NOTIFICATION);
//            intentFilter.addAction(ACTION_REGISTRATION);
//            LocalBroadcastManager.getInstance(this).registerReceiver(
//                    localBroadcastReceiver, intentFilter);
//            isReceiverRegistered = true;
//        }
//    }

//    private void unregisterReceiver() {
//        LocalBroadcastManager.getInstance(this).unregisterReceiver(localBroadcastReceiver);
//        isReceiverRegistered = false;
//    }

//    private class LocalBroadcastReceiver extends BroadcastReceiver {
//
//        @Override
//        public void onReceive(Context context, Intent intent) {
//            String action = intent.getAction();
//            if (action != null) {
//                if (action.equals(ACTION_REGISTRATION)) {
//                    handleRegistration(intent);
//                } else if (action.equals(ACTION_VIDEO_NOTIFICATION)) {
//                    handleVideoNotificationIntent(intent);
//                }
//            }
//        }
//    }

    /*
     * Creates a connect UI dialog to handle notifications
     */
//    private void showVideoNotificationConnectDialog(String title, String roomName) {
//        EditText roomEditText = new EditText(this);
//        roomEditText.setText(roomName);
//        // Use the default color instead of the disabled color
//        int currentColor = roomEditText.getCurrentTextColor();
//        roomEditText.setEnabled(false);
//        roomEditText.setTextColor(currentColor);
//        alertDialog = createConnectDialog(title,
//                roomEditText,
//                videoNotificationConnectClickListener(roomEditText),
//                cancelConnectDialogClickListener(),
//                this);
//        alertDialog.show();
//    }

    @SuppressLint("SetTextI18n")
    @Override
    protected void onResume() {
        super.onResume();
//        registerReceiver();
        /*
         * If the local video track was released when the app was put in the background, recreate.
         */
        if (localVideoTrack == null &&
                checkPermissionForCameraAndMicrophone() &&
                cameraCapturer != null) {
            localVideoTrack = LocalVideoTrack.create(this, true, cameraCapturer);
            if (localVideoTrack != null) {
                if (isVoiceCall) {
                    localVideoTrack.enable(false);
                } else {
                    localVideoTrack.enable(switchCameraActionFab.getVisibility() == View.VISIBLE);
                }
                localVideoTrack.addRenderer(localVideoView);
            }


            /*
             * If connected to a Room then share the local video track.
             */
            if (localParticipant != null) {
                if (localVideoTrack != null) {
                    localParticipant.publishTrack(localVideoTrack);
                }
            }
        }

        /*
         * Update reconnecting UI
         */
        if (room != null) {
            reconnectingProgressBar.setVisibility((room.getState() != Room.State.RECONNECTING) ?
                    View.GONE :
                    View.VISIBLE);
            statusTextView.setText("Connected to " + room.getName());
        }
    }

    @Override
    protected void onPause() {
//        unregisterReceiver();
        /*
         * Release the local video track before going in the background. This ensures that the
         * camera can be used by other applications while this app is in the background.
         *
         * If this local video track is being shared in a Room, participants will be notified
         * that the track has been unpublished.
         */
        if (localVideoTrack != null) {
            /*
             * If this local video track is being shared in a Room, unpublish from room before
             * releasing the video track. Participants will be notified that the track has been
             * removed.
             */
            if (localParticipant != null) {
                localParticipant.unpublishTrack(localVideoTrack);
            }
            localVideoTrack.release();
            localVideoTrack = null;
        }
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        /*
         * Always disconnect from the room before leaving the Activity to
         * ensure any memory allocated to the Room resource is freed.
         */
        if (room != null && room.getState() != Room.State.DISCONNECTED) {
            room.disconnect();
            disconnectedFromOnDestroy = true;
            isTimerStart = false;
        }

        /*
         * Release the local audio and video tracks ensuring any memory allocated to audio
         * or video is freed.
         */
        if (localAudioTrack != null) {
            localAudioTrack.release();
            localAudioTrack = null;
        }
        if (localVideoTrack != null) {
            localVideoTrack.release();
            localVideoTrack = null;
        }

        super.onDestroy();
    }

    private boolean checkPermissionForCameraAndMicrophone() {
        int resultCamera = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA);
        int resultMic = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO);
        return resultCamera == PackageManager.PERMISSION_GRANTED &&
                resultMic == PackageManager.PERMISSION_GRANTED;
    }

    private void requestPermissionForCameraAndMicrophone() {
        /*if (ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.CAMERA) ||
                ActivityCompat.shouldShowRequestPermissionRationale(this,
                        Manifest.permission.RECORD_AUDIO)) {
            Toast.makeText(this,
                    R.string.permissions_needed,
                    Toast.LENGTH_LONG).show();
        } else {
            ActivityCompat.requestPermissions(
                    this,
                    new String[]{Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO},
                    CAMERA_MIC_PERMISSION_REQUEST_CODE);
        }*/
        ActivityCompat.requestPermissions(
                this,
                new String[]{Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO},
                CAMERA_MIC_PERMISSION_REQUEST_CODE);
    }

    private void createLocalTracks() {
        // Share your microphone
        localAudioTrack = LocalAudioTrack.create(this, true);

        // Share your camera
        cameraCapturer = new CameraCapturer(this, getAvailableCameraSource());
        localVideoTrack = LocalVideoTrack.create(this, true, cameraCapturer);
        if (localVideoTrack != null) {
            localVideoTrack.enable(!isVoiceCall);
            primaryVideoView.setMirror(true);
            localVideoTrack.addRenderer(primaryVideoView);
            localVideoView = primaryVideoView;
        }

    }

    private CameraSource getAvailableCameraSource() {
        return (CameraCapturer.isSourceAvailable(CameraSource.FRONT_CAMERA)) ?
                (CameraSource.FRONT_CAMERA) :
                (CameraSource.BACK_CAMERA);
    }

    private void connectToRoom(/*String roomName*/) {
        createLocalTracks();
        intializeUI();
        enableAudioFocus(true);
        enableVolumeControl(true);

        ConnectOptions.Builder connectOptionsBuilder = new ConnectOptions.Builder(token)
                .roomName(roomName);

        /*
         * Add local audio track to connect options to share with participants.
         */
        if (localAudioTrack != null) {
            connectOptionsBuilder
                    .audioTracks(Collections.singletonList(localAudioTrack));
        }

        /*
         * Add local video track to connect options to share with participants.
         */
        if (localVideoTrack != null) {
            connectOptionsBuilder.videoTracks(Collections.singletonList(localVideoTrack));
        }

        room = Video.connect(this, connectOptionsBuilder.build(), roomListener());
        setDisconnectBehavior();
    }

//    void notify(final String roomName) {
//        String inviteJsonString;
//        Invite invite = new Invite(identity, roomName);
//
//        /*
//         * Use Twilio Notify to let others know you are connecting to a Room
//         */
//        Notification notification = new Notification(
//                "Join " + identity + " in room " + roomName,
//                identity + " has invited you to join video room " + roomName,
//                invite.getMap(),
//                NOTIFY_TAGS);
//        TwilioSDKStarterAPI.notify(notification).enqueue(new Callback<Void>() {
//            @Override
//            public void onResponse(Call<Void> call, Response<Void> response) {
//                if (!response.isSuccess()) {
//                    String message = "Sending notification failed: " + response.code() + " " + response.message();
//                    Log.e(TAG, message);
//                    statusTextView.setText(message);
//                }
//            }
//
//            @Override
//            public void onFailure(Call<Void> call, Throwable t) {
//                String message = "Sending notification failed: " + t.getMessage();
//                Log.e(TAG, message);
//                statusTextView.setText(message);
//            }
//        });
//    }

    /*
     * The initial state when there is no active conversation.
     */
    private void intializeUI() {
        //connectActionFab.setImageDrawable(ContextCompat.getDrawable(this, R.drawable.ic_videocam));
        //connectActionFab.setVisibility(View.VISIBLE);
        //connectActionFab.setOnClickListener(connectActionClickListener());
        switchCameraActionFab.setOnClickListener(switchCameraClickListener());
        localVideoActionFab.setOnClickListener(localVideoClickListener());
        muteActionFab.setOnClickListener(muteClickListener());
//        turnSpeakerOnMenuItem.setOnClickListener(menuClickListener());
//        turnSpeakerOffMenuItem.setOnClickListener(menuClickListener());
        turnSpeakerOn.setOnClickListener(menuClickListener());
        turnSpeakerOff.setOnClickListener(menuClickListener());
    }

    /*
     * The behavior applied to disconnect
     */
    private void setDisconnectBehavior() {
//        connectActionFab.setImageDrawable(ContextCompat.getDrawable(this, R.drawable.ic_call_end));
        connectActionFab.setOnClickListener(disconnectClickListener());
        backButton.setOnClickListener(disconnectClickListener());
    }

    /*
     * Creates a connect UI dialog
     */
//    private void showConnectDialog() {
//        EditText roomEditText = new EditText(this);
//        String title = "Connect to a video room";
//        roomEditText.setHint("room name");
//        alertDialog = createConnectDialog(title,
//                roomEditText,
//                connectClickListener(roomEditText),
//                cancelConnectDialogClickListener(),
//                this);
//        alertDialog.setVisibility(View.VISIBLE);
//    }

    /*
     * Called when remote participant joins the room
     */
    @SuppressLint("SetTextI18n")
    private void addRemoteParticipant(RemoteParticipant remoteParticipant) {
        /*
         * This app only displays video for one additional participant per Room
         */
        if (thumbnailVideoView.getVisibility() == View.VISIBLE) {
            Snackbar.make(connectActionFab,
                    "Rendering multiple participants not supported in this app",
                    Snackbar.LENGTH_LONG)
                    .show();
            return;
        }
        remoteParticipantIdentity = remoteParticipant.getIdentity();
        statusTextView.setText("RemoteParticipant " + remoteParticipantIdentity + " joined");

        /*
         * Add remote participant renderer
         */
        if (remoteParticipant.getRemoteVideoTracks().size() > 0) {
            @NonNull RemoteVideoTrackPublication remoteVideoTrackPublication =
                    remoteParticipant.getRemoteVideoTracks().get(0);

            /*
             * Only render video tracks that are subscribed to
             */
            if (remoteVideoTrackPublication.isTrackSubscribed()) {
                RemoteVideoTrack remoteVideoTrack = remoteVideoTrackPublication.getRemoteVideoTrack();
                if (remoteVideoTrack != null) {
                    addRemoteParticipantVideo(remoteVideoTrack);
                }
            }
        }

        /*
         * Start listening for participant media events
         */
        remoteParticipant.setListener(mediaListener());
    }

    /*
     * Set primary view as renderer for participant video track
     */
    private void addRemoteParticipantVideo(VideoTrack videoTrack) {
        moveLocalVideoToThumbnailView();
        primaryVideoView.setMirror(false);
        videoTrack.addRenderer(primaryVideoView);
    }

    private void moveLocalVideoToThumbnailView() {
        if (thumbnailVideoView.getVisibility() == View.GONE) {
            if (!isVoiceCall) {
                thumbnailVideoView.setVisibility(View.VISIBLE);
            }
            if (localVideoTrack != null) {
                localVideoTrack.removeRenderer(primaryVideoView);
                localVideoTrack.addRenderer(thumbnailVideoView);
                if (isVoiceCall) {
                    localVideoTrack.enable(false);
                }
            }
            localVideoView = thumbnailVideoView;
            thumbnailVideoView.setMirror(cameraCapturer.getCameraSource() ==
                    CameraSource.FRONT_CAMERA);
        }
    }

    /*
     * Called when participant leaves the room
     */
    @SuppressLint("SetTextI18n")
    private void removeParticipant(RemoteParticipant remoteParticipant) {
        statusTextView.setText("Participant " + remoteParticipant.getIdentity() + " left.");
        if (!remoteParticipant.getIdentity().equals(remoteParticipantIdentity)) {
            return;
        }

        /*
         * Remove participant renderer
         */
        if (remoteParticipant.getRemoteVideoTracks().size() > 0) {
            @NonNull RemoteVideoTrackPublication remoteVideoTrackPublication =
                    remoteParticipant.getRemoteVideoTracks().get(0);

            /*
             * Remove video only if subscribed to participant track.
             */
            if (remoteVideoTrackPublication.isTrackSubscribed()) {
                RemoteVideoTrack remoteVideoTrack = remoteVideoTrackPublication.getRemoteVideoTrack();
                if (remoteVideoTrack != null) {
                    removeParticipantVideo(remoteVideoTrack);
                }
            }
        }
        moveLocalVideoToPrimaryView();
    }

    private void removeParticipantVideo(VideoTrack videoTrack) {
        videoTrack.removeRenderer(primaryVideoView);
    }

    private void moveLocalVideoToPrimaryView() {
        if (thumbnailVideoView.getVisibility() == View.VISIBLE) {
            localVideoTrack.removeRenderer(thumbnailVideoView);
            thumbnailVideoView.setVisibility(View.GONE);
            localVideoTrack.addRenderer(primaryVideoView);
            localVideoView = primaryVideoView;
            primaryVideoView.setMirror(cameraCapturer.getCameraSource() ==
                    CameraSource.FRONT_CAMERA);
        }
    }

    /*
     * Room events listener
     */
    @SuppressLint("SetTextI18n")
    private Room.Listener roomListener() {
        return new Room.Listener() {
            @Override
            public void onConnected(@NonNull Room room) {
                localParticipant = room.getLocalParticipant();
                statusTextView.setText("Connected to " + room.getName());
                setTitle(room.getName());

                if (!room.getRemoteParticipants().isEmpty()) {
                    addRemoteParticipant(room.getRemoteParticipants().get(0));
                }
                isTimerStart = true;
                startTimer();
                try {
                    JSONObject jsonObject = new JSONObject();
                    jsonObject.put("status", "CONNECTED");
                    if (TwilioCallingKitModule.reactContext != null) {
                        TwilioCallingKitModule.reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                                .emit("TWILIO_ON_STATE_CHANGE", jsonObject.toString());
                    }
                } catch (Exception e1) {
                    e1.printStackTrace();
                }
            }

            @Override
            public void onConnectFailure(@NonNull Room room, @NonNull TwilioException e) {
                statusTextView.setText("Failed to connect");
                try {
                    JSONObject jsonObject = new JSONObject();
                    jsonObject.put("status", "FAIL_TO_CONNECT");
                    if (TwilioCallingKitModule.reactContext != null) {
                        TwilioCallingKitModule.reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                                .emit("TWILIO_ON_STATE_CHANGE", jsonObject.toString());
                    }
                } catch (Exception e1) {
                    e1.printStackTrace();
                }
                VideoCallingActivity.this.finish();
            }

            @Override
            public void onDisconnected(@NonNull Room room, TwilioException e) {
                localParticipant = null;
                statusTextView.setText("Disconnected from " + room.getName());
                reconnectingProgressBar.setVisibility(View.GONE);
                VideoCallingActivity.this.room = null;
                enableAudioFocus(false);
                enableVolumeControl(false);
                isTimerStart = false;
                // Only reinitialize the UI if disconnect was not called from onDestroy()
                if (!disconnectedFromOnDestroy) {
                    intializeUI();
                    moveLocalVideoToPrimaryView();
                }
                try {
                    JSONObject jsonObject = new JSONObject();
                    jsonObject.put("status", "DISCONNECTED");
                    if (TwilioCallingKitModule.reactContext != null) {
                        TwilioCallingKitModule.reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                                .emit("TWILIO_ON_STATE_CHANGE", jsonObject.toString());
                    }
                } catch (Exception e1) {
                    e1.printStackTrace();
                }
                VideoCallingActivity.this.finish();
            }

            @Override
            public void onParticipantConnected(@NonNull Room room, @NonNull RemoteParticipant remoteParticipant) {
                addRemoteParticipant(remoteParticipant);
            }

            @Override
            public void onParticipantDisconnected(@NonNull Room room, @NonNull RemoteParticipant remoteParticipant) {
                removeParticipant(remoteParticipant);
            }

            @Override
            public void onRecordingStarted(@NonNull Room room) {
                /*
                 * Indicates when media shared to a Room is being recorded. Note that
                 * recording is only available in our Group Rooms developer preview.
                 */
            }

            @Override
            public void onRecordingStopped(@NonNull Room room) {
                /*
                 * Indicates when media shared to a Room is no longer being recorded. Note that
                 * recording is only available in our Group Rooms developer preview.
                 */
            }

            @Override
            public void onReconnecting(@NonNull Room room, @NonNull TwilioException exception) {
                statusTextView.setText("Reconnecting to " + room.getName());
                reconnectingProgressBar.setVisibility(View.VISIBLE);
            }

            @Override
            public void onReconnected(@NonNull Room room) {
                statusTextView.setText("Connected to " + room.getName());
                reconnectingProgressBar.setVisibility(View.GONE);
            }
        };
    }

    @SuppressLint("SetTextI18n")
    private RemoteParticipant.Listener mediaListener() {
        return new RemoteParticipant.Listener() {
            @Override
            public void onAudioTrackPublished(@NonNull RemoteParticipant remoteParticipant,
                                              @NonNull RemoteAudioTrackPublication remoteAudioTrackPublication) {
                statusTextView.setText("onAudioTrackPublished");
            }

            @Override
            public void onAudioTrackUnpublished(@NonNull RemoteParticipant remoteParticipant,
                                                @NonNull RemoteAudioTrackPublication remoteAudioTrackPublication) {
                statusTextView.setText("onAudioTrackPublished");
            }

            @Override
            public void onVideoTrackPublished(@NonNull RemoteParticipant remoteParticipant,
                                              @NonNull RemoteVideoTrackPublication remoteVideoTrackPublication) {
                statusTextView.setText("onVideoTrackPublished");
            }

            @Override
            public void onVideoTrackUnpublished(@NonNull RemoteParticipant remoteParticipant,
                                                @NonNull RemoteVideoTrackPublication remoteVideoTrackPublication) {
                statusTextView.setText("onVideoTrackUnpublished");
            }

            @Override
            public void onDataTrackPublished(@NonNull RemoteParticipant remoteParticipant,
                                             @NonNull RemoteDataTrackPublication remoteDataTrackPublication) {
                statusTextView.setText("onDataTrackPublished");
            }

            @Override
            public void onDataTrackUnpublished(@NonNull RemoteParticipant remoteParticipant,
                                               @NonNull RemoteDataTrackPublication remoteDataTrackPublication) {
                statusTextView.setText("onDataTrackUnpublished");
            }

            @Override
            public void onAudioTrackSubscribed(@NonNull RemoteParticipant remoteParticipant,
                                               @NonNull RemoteAudioTrackPublication remoteAudioTrackPublication,
                                               @NonNull RemoteAudioTrack remoteAudioTrack) {
                statusTextView.setText("onAudioTrackSubscribed");
            }

            @Override
            public void onAudioTrackUnsubscribed(@NonNull RemoteParticipant remoteParticipant,
                                                 @NonNull RemoteAudioTrackPublication remoteAudioTrackPublication,
                                                 @NonNull RemoteAudioTrack remoteAudioTrack) {
                statusTextView.setText("onAudioTrackUnsubscribed");
            }

            @Override
            public void onAudioTrackSubscriptionFailed(@NonNull RemoteParticipant remoteParticipant,
                                                       @NonNull RemoteAudioTrackPublication remoteAudioTrackPublication,
                                                       @NonNull TwilioException twilioException) {
                statusTextView.setText("onAudioTrackSubscriptionFailed");
            }

            @Override
            public void onVideoTrackSubscribed(@NonNull RemoteParticipant remoteParticipant,
                                               @NonNull RemoteVideoTrackPublication remoteVideoTrackPublication,
                                               @NonNull RemoteVideoTrack remoteVideoTrack) {
                statusTextView.setText("onVideoTrackSubscribed");
                addRemoteParticipantVideo(remoteVideoTrack);
            }

            @Override
            public void onVideoTrackUnsubscribed(@NonNull RemoteParticipant remoteParticipant,
                                                 @NonNull RemoteVideoTrackPublication remoteVideoTrackPublication,
                                                 @NonNull RemoteVideoTrack remoteVideoTrack) {
                statusTextView.setText("onVideoTrackUnsubscribed");
                removeParticipantVideo(remoteVideoTrack);
            }

            @Override
            public void onVideoTrackSubscriptionFailed(@NonNull RemoteParticipant remoteParticipant,
                                                       @NonNull RemoteVideoTrackPublication remoteVideoTrackPublication,
                                                       @NonNull TwilioException twilioException) {
                statusTextView.setText("onVideoTrackSubscriptionFailed");
                Snackbar.make(connectActionFab,
                        String.format("Failed to subscribe to %s video track",
                                remoteParticipant.getIdentity()),
                        Snackbar.LENGTH_LONG)
                        .show();
            }

            @Override
            public void onDataTrackSubscribed(@NonNull RemoteParticipant remoteParticipant,
                                              @NonNull RemoteDataTrackPublication remoteDataTrackPublication,
                                              @NonNull RemoteDataTrack remoteDataTrack) {
                statusTextView.setText("onDataTrackSubscribed");
            }

            @Override
            public void onDataTrackUnsubscribed(@NonNull RemoteParticipant remoteParticipant,
                                                @NonNull RemoteDataTrackPublication remoteDataTrackPublication,
                                                @NonNull RemoteDataTrack remoteDataTrack) {
                statusTextView.setText("onDataTrackUnsubscribed");
            }

            @Override
            public void onDataTrackSubscriptionFailed(@NonNull RemoteParticipant remoteParticipant,
                                                      @NonNull RemoteDataTrackPublication remoteDataTrackPublication,
                                                      @NonNull TwilioException twilioException) {
                statusTextView.setText("onDataTrackSubscriptionFailed");
            }

            @Override
            public void onAudioTrackEnabled(@NonNull RemoteParticipant remoteParticipant,
                                            @NonNull RemoteAudioTrackPublication remoteAudioTrackPublication) {
            }

            @Override
            public void onAudioTrackDisabled(@NonNull RemoteParticipant remoteParticipant,
                                             @NonNull RemoteAudioTrackPublication remoteAudioTrackPublication) {
            }

            @Override
            public void onVideoTrackEnabled(@NonNull RemoteParticipant remoteParticipant,
                                            @NonNull RemoteVideoTrackPublication remoteVideoTrackPublication) {
            }

            @Override
            public void onVideoTrackDisabled(@NonNull RemoteParticipant remoteParticipant,
                                             @NonNull RemoteVideoTrackPublication remoteVideoTrackPublication) {
            }
        };
    }

//    private DialogInterface.OnClickListener connectClickListener(final EditText roomEditText) {
//        return (dialog, which) -> {
//            final String roomName = roomEditText.getText().toString();
//            /*
//             * Connect to room
//             */
//            connectToRoom(roomName);
//            /*
//             * Notify other participants to join the room
//             */
//            //VideoCallingActivity.this.notify(roomName);
//        };
//    }

//    private DialogInterface.OnClickListener videoNotificationConnectClickListener(final EditText roomEditText) {
//        return (dialog, which) -> {
//            /*
//             * Connect to room
//             */
//            connectToRoom(roomEditText.getText().toString());
//        };
//    }

    private View.OnClickListener disconnectClickListener() {
        return v -> {
            /*
             * Disconnect from room
             */
            if (room != null) {
                room.disconnect();
                isTimerStart = false;
            }
            intializeUI();
        };
    }

//    private View.OnClickListener connectActionClickListener() {
//        return v -> connectToRoom();
//    }

//    private DialogInterface.OnClickListener cancelConnectDialogClickListener() {
//        return (dialog, which) -> {
//            intializeUI();
//            alertDialog.dismiss();
//        };
//    }

    private View.OnClickListener switchCameraClickListener() {
        return v -> {
            if (cameraCapturer != null) {
                CameraSource cameraSource = cameraCapturer.getCameraSource();
                cameraCapturer.switchCamera();
                if (thumbnailVideoView.getVisibility() == View.VISIBLE) {
                    thumbnailVideoView.setMirror(cameraSource == CameraSource.BACK_CAMERA);
                } else {
                    primaryVideoView.setMirror(cameraSource == CameraSource.BACK_CAMERA);
                }
            }
        };
    }

    private View.OnClickListener localVideoClickListener() {
        return v -> {
            /*
             * Enable/disable the local video track
             */
            if (localVideoTrack != null) {
                boolean enable = !localVideoTrack.isEnabled();
                localVideoTrack.enable(enable);
                int icon;
                if (enable) {
                    icon = R.drawable.ic_videocam;
                    switchCameraActionFab.setVisibility(View.VISIBLE);
                    renderVideoCallUI();
                } else {
                    icon = R.drawable.ic_videocam_off;
                    switchCameraActionFab.setVisibility(View.GONE);
                }
                localVideoActionFab.setImageDrawable(
                        ContextCompat.getDrawable(VideoCallingActivity.this, icon));
            }
        };
    }

    private View.OnClickListener muteClickListener() {
        return v -> {
            /*
             * Enable/disable the local audio track. The results of this operation are
             * signaled to other Participants in the same Room. When an audio track is
             * disabled, the audio is muted.
             */
            if (localAudioTrack != null) {
                boolean enable = !localAudioTrack.isEnabled();
                localAudioTrack.enable(enable);
                int icon = enable ?
                        R.drawable.ic_mic_on : R.drawable.ic_mic_off;
                muteActionFab.setImageDrawable(ContextCompat.getDrawable(
                        VideoCallingActivity.this, icon));
            }
        };
    }

    private View.OnClickListener menuClickListener() {
        return v -> {
            int i = v.getId();
            /*if (i == R.id.menu_turn_speaker_on || i == R.id.menu_turn_speaker_off) {
                boolean expectedSpeakerPhoneState = !audioManager.isSpeakerphoneOn();
                audioManager.setSpeakerphoneOn(expectedSpeakerPhoneState);
                if (expectedSpeakerPhoneState) {
                    turnSpeakerOffMenuItem.setVisibility(View.VISIBLE);
                    turnSpeakerOnMenuItem.setVisibility(View.GONE);
                } else {
                    turnSpeakerOffMenuItem.setVisibility(View.GONE);
                    turnSpeakerOnMenuItem.setVisibility(View.VISIBLE);
                }
            } else */
            if (i == R.id.turn_speaker_on || i == R.id.turn_speaker_off) {
                boolean expectedSpeakerPhoneState = !audioManager.isSpeakerphoneOn();
                audioManager.setSpeakerphoneOn(expectedSpeakerPhoneState);
                if (expectedSpeakerPhoneState) {
                    turnSpeakerOff.setVisibility(View.VISIBLE);
                    turnSpeakerOn.setVisibility(View.GONE);
                } else {
                    turnSpeakerOff.setVisibility(View.GONE);
                    turnSpeakerOn.setVisibility(View.VISIBLE);
                }
            }
        };
    }

    private void enableAudioFocus(boolean focus) {
        if (focus) {
            previousAudioMode = audioManager.getMode();
            // Request audio focus before making any device switch.
            requestAudioFocus();
            /*
             * Use MODE_IN_COMMUNICATION as the default audio mode. It is required
             * to be in this mode when playout and/or recording starts for the best
             * possible VoIP performance. Some devices have difficulties with
             * speaker mode if this is not set.
             */
            audioManager.setMode(AudioManager.MODE_IN_COMMUNICATION);
        } else {
            audioManager.setMode(previousAudioMode);
            audioManager.abandonAudioFocus(null);
        }
    }

    private void requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            AudioAttributes playbackAttributes = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build();
            AudioFocusRequest focusRequest =
                    new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                            .setAudioAttributes(playbackAttributes)
                            .setAcceptsDelayedFocusGain(true)
                            .setOnAudioFocusChangeListener(
                                    i -> {
                                    })
                            .build();
            audioManager.requestAudioFocus(focusRequest);
        } else {
            audioManager.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT);
        }
    }

    private void enableVolumeControl(boolean volumeControl) {
        if (volumeControl) {
            /*
             * Enable changing the volume using the up/down keys during a conversation
             */
            setVolumeControlStream(AudioManager.STREAM_VOICE_CALL);
        } else {
            setVolumeControlStream(getVolumeControlStream());
        }
    }

//    public static AlertDialog createConnectDialog(String title,
//                                                  EditText roomEditText,
//                                                  DialogInterface.OnClickListener callParticipantsClickListener,
//                                                  DialogInterface.OnClickListener cancelClickListener,
//                                                  Context context) {
//        AlertDialog.Builder alertDialogBuilder = new AlertDialog.Builder(context);
//        alertDialogBuilder.setIcon(R.drawable.ic_video_call_black_24dp);
//        alertDialogBuilder.setTitle(title);
//        alertDialogBuilder.setPositiveButton("Connect", callParticipantsClickListener);
//        alertDialogBuilder.setNegativeButton("Cancel", cancelClickListener);
//        alertDialogBuilder.setCancelable(false);
//        alertDialogBuilder.setView(roomEditText);
//        return alertDialogBuilder.create();
//    }

}