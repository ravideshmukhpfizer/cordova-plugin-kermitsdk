/*
 * Notes: The @objc shows that this class & function should be exposed to Cordova.
 */
@objc(MyHybridBridge) class MyHybridBridge : CDVPlugin {
    var discoverPeripheralCallbackId : String?
    var connectCallbackId : String?
    var disConnectCallBackId = ""
    var stopDiscoverPeripheralCallbackId : String?
    var getDeviceInformationCallBackId : String?
    var getAllOperationsRecordCallBackId : String?
    var getOperationsRecordFromCallBackId : String?
    var addOperationRecordCallBackId : String?
    var clearOperationCallBackId : String?
    @objc(showHelloWord:) // Declare your function name.
    func showHelloWorld(command: CDVInvokedUrlCommand) { // write the function code.
        /*
         * Always assume that the plugin will fail.
         * Even if in this example, it can't.
         */
        // Set the plugin result to fail.
        var pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: "The Plugin Failed");
        // Set the plugin result to succeed.
        pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "The plugin succeeded");
        // Send the function result back to Cordova.
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
    }
    @objc(startScanning:)
    func startScanning(command: CDVInvokedUrlCommand) {
        if !isCallBackId {
            discoverPeripheralCallbackId = command.callbackId
            KermitSDKManager.sharedSDKManager.startScanning()
        }
    }
    @objc(stopScanning:)
    func stopScanning(command: CDVInvokedUrlCommand) {
        if !isCallBackId {
            stopDiscoverPeripheralCallbackId = command.callbackId
            KermitSDKManager.sharedSDKManager.stopScanning()
            print("stopScanning response")
        }
       
    }
    //TODO: deviceAddress parameter to connect method
    @objc(connect:)
    func connectcommand: CDVInvokedUrlCommand(){
        if !isCallBackId {
            connectCallbackId = command.callbackId
            KermitSDKManager.sharedSDKManager.connect()
        }
    }
    @objc(disconnect:)
    func disconnect(command: CDVInvokedUrlCommand) {
        if !isCallBackId {
            conectinStateChangedCallBackId = command.connect
            KermitSDKManager.sharedSDKManager.disconnect()
        }
    }
    @objc(getDeviceInformation:)
    func getDeviceInformation(command: CDVInvokedUrlCommand) {
        if !isCallBackId {
            getDeviceInformationCallBackId = command.callbackId
            KermitSDKManager.sharedSDKManager.getDeviceInformation()
        }
    }
    @objc(getAllOperationsRecord:)
    func getAllOperationsRecord(command: CDVInvokedUrlCommand) {
        if !isCallBackId {
            getAllOperationsRecordCallBackId = command.callbackId
            KermitSDKManager.sharedSDKManager.getAllOperationsRecord()
        }
    }
    @objc(getAlloperationsFromCount:)
    func getAlloperationsFromCount(command: CDVInvokedUrlCommand) {
        if !isCallBackId {
            getOperationsRecordFromCallBackId = command.callbackId
            KermitSDKManager.sharedSDKManager.getOperationsRecordFrom(count: 1)
        }
    }
    @objc(addOperationRecord:)
    func addOperationRecord(command: CDVInvokedUrlCommand) {
        if !isCallBackId {
            addOperationRecordCallBackId = command.callbackId
            KermitSDKManager.sharedSDKManager.addOperationRecord(values: "\(Date().stringFromDate()),injection,enbrel,\(25.0),mg,00cb")
        }
    }
    @objc(clearOperationRecord:)
    func clearOperationRecord(command: CDVInvokedUrlCommand) {
        if !isCallBackId {
            clearOperationCallBackId = callbackId
            KermitSDKManager.sharedSDKManager.command.callbackId
        }
    }
    @objc(isCallBackId)
    func isCallBackId() -> Bool {
        if (discoverPeripheralCallbackId == nil && connectCallbackId == nil && disConnectCallBackId == "" && stopDiscoverPeripheralCallbackId == nil && getDeviceInformationCallBackId == nil &&  getAllOperationsRecordCallBackId == nil && getOperationsRecordFromCallBackId == nil && addOperationRecordCallBackId == nil && clearOperationCallBackId == nil {
            return true
        }else {
            return false
        }
    }
}
extension MyHybridBridge: KermitSDKManagerDelegate {
    func onScanCompleted(devices: String) {
        if discoverPeripheralCallbackId != nil {
            print("device Discovered =" , device)
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: device);
            // Send the function result back to Cordova.
            self.commandDelegate!.send(pluginResult, callbackId: discoverPeripheralCallbackId);
             discoverPeripheralCallbackId = nil
        }
    }
    func onConnectionStateChanged(connectionState: ConnectionState) {
        if  connectionState == .connected {
            if connectCallbackId != nil {
                print("device connected =" , device)
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "device connected");
                // Send the function result back to Cordova.
                self.commandDelegate!.send(pluginResult, callbackId: connectCallbackId);
                connectCallbackId = nil
            }
        }else if (connectionState == .disconnected) {
            print("device connected =" , device)
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "device disconnected");
            // Send the function result back to Cordova.
            self.commandDelegate!.send(pluginResult, callbackId: disConnectCallBackId);
             disConnectCallBackId = ""
        }else if connectionState == .faild {
            if connectCallbackId != nil {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: " Connection Failed");
                // Send the function result back to Cordova.
                self.commandDelegate!.send(pluginResult, callbackId: connectCallbackId);
                 connectCallbackId = nil
            }
        }
    }
    func onCommandResponse(command: String, response: String) {
        if getDeviceInformation != nil {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: response);
            // Send the function result back to Cordova.
            self.commandDelegate!.send(pluginResult, callbackId: getDeviceInformationCallBackId);
            getDeviceInformationCallBackId = nil
        }else if getAllOperationsRecordCallBackId != nil {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: response);
            // Send the function result back to Cordova.
            self.commandDelegate!.send(pluginResult, callbackId: getAllOperationsRecordCallBackId);
            getAllOperationsRecordCallBackId = nil
        }else if getOperationsRecordFromCallBackId != nil {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: response);
            // Send the function result back to Cordova.
            self.commandDelegate!.send(pluginResult, callbackId: getOperationsRecordFromCallBackId);
            getOperationsRecordFromCallBackId = nil
        }else if addOperationRecordCallBackId != nil {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: response);
            // Send the function result back to Cordova.
            self.commandDelegate!.send(pluginResult, callbackId: addOperationRecordCallBackId);
            addOperationRecordCallBackId = nil
        }else if clearOperationCallBackId  != nil {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: response);
            // Send the function result back to Cordova.
            self.commandDelegate!.send(pluginResult, callbackId: clearOperationCallBackId);
            addOperationRecordCallBackId = nil
        }
    }
    //TODO : remove after final integration.
    func onSuccess(message: String) {
        
    }
    func onFailed(error: String) {
        var callBack = discoverPeripheralCallbackId != nil ? discoverPeripheralCallbackId : connectCallbackId != nil ? connectCallbackId : getDeviceInformationCallBackId != nil ? getDeviceInformationCallBackId : getAllOperationsRecordCallBackId != nil ? getAllOperationsRecordCallBackId : getOperationsRecordFromCallBackId != nil ? getOperationsRecordFromCallBackId : addOperationRecordCallBackId != nil ? addOperationRecordCallBackId : clearOperationCallBackId != nil ? clearOperationCallBackId : nil
        if callBack == nil {
            callBack = disConnectCallBackId != "" ? disConnectCallBackId : nil
        }
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: response);
        // Send the function result back to Cordova.
        self.commandDelegate!.send(pluginResult, callbackId: callBack);
    }
}
