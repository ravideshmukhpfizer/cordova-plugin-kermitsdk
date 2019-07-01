
import { Injectable } from '@angular/core';
import { Cordova, Plugin, IonicNativePlugin } from '@ionic-native/core';

@Plugin({
  pluginName: 'MyHybridBridge',
  plugin: 'cordova-plugin-kermitsdk.MyHybridBridge',
  pluginRef: 'MyHybridBridge',
  repo: 'https://github.com/ravideshmukhpfizer/cordova-plugin-kermitsdk',
  platforms: ['iOS']
})
@Injectable()
export class MyHybridBridge extends IonicNativePlugin {

  @Cordova({
    successIndex: 0,
    errorIndex: 1
  })
  showHelloWorld(): Promise<any> {
    return;
    }

}
