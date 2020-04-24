import { PureComponent } from "react";
import { NativeModules } from 'react-native';

const { TwilioCallingKit } = NativeModules;
class RNTwilioCallingKit extends PureComponent {

    static connect(props, callback) {
        TwilioCallingKit.connect(
            props,
            (result) => {
                console.log("aa ------- result=>", result);
                if (callback) {
                    callback(result)
                }
            },
            (error) => {
                console.log("aa ------- error=>", error);
                if (callback) {
                    callback(error)
                }
            }
        );
    }
}

export { RNTwilioCallingKit as TwilioCallingKit };


