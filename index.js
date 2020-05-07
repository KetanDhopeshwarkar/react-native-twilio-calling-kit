import { PureComponent } from "react";
import { NativeEventEmitter, NativeModules, Platform } from 'react-native';

const { TwilioCallingKit } = NativeModules;
class RNTwilioCallingKit extends PureComponent {

    componentWillUnmount = () => {
        if (this.eventEmitter) {
            this.eventEmitter.remove();
            this.eventEmitter = null;
        }
    }

    static connect(props, callback) {
        this.eventEmitter = new NativeEventEmitter(TwilioCallingKit)
            .addListener('TWILIO_ON_STATE_CHANGE', (data) => {
                let result = Platform.OS === 'ios' ? data : JSON.parse(data);
                if (result.status == 'DISCONNECTED' || result.status == 'FAIL_TO_CONNECT') {
                    this.eventEmitter.remove();
                    this.eventEmitter = null;
                }
                if (callback) {
                    callback(result);
                }
            });
        TwilioCallingKit.connect(props);
    }
}

export { RNTwilioCallingKit as TwilioCallingKit };
