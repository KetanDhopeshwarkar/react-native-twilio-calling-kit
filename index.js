import { PureComponent } from "react";
import { NativeEventEmitter, NativeModules } from 'react-native';

const { TwilioCallingKit } = NativeModules;
class RNTwilioCallingKit extends PureComponent {

    static connect(props, callback) {
        let nee = new NativeEventEmitter(TwilioCallingKit);
        nee.addListener('TWILIO_ON_STATE_CHANGE', (data) => {
            let result = JSON.parse(data);
            if (result.status == 'DISCONNECTED' || result.status == 'FAIL_TO_CONNECT') {
                nee.removeAllListeners("TWILIO_ON_STATE_CHANGE");
            }
            if (callback) {
                callback(result);
            }
        });
        TwilioCallingKit.connect(
            props,
            (result) => {
                console.log("aa ------- result=>", result);
            },
            (error) => {
                console.log("aa ------- error=>", error);
            }
        );
    }
}

export { RNTwilioCallingKit as TwilioCallingKit };


