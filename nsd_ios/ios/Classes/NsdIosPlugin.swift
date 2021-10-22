import Flutter
import UIKit

private let channelName = "com.haberey/nsd"

public class NsdIosPlugin: NSObject, FlutterPlugin, NetServiceBrowserDelegate, NetServiceDelegate {

    // NetServiceBrowser is deprecated but Network Framework only provides equivalent functionality since iOS 13
    // see https://developer.apple.com/forums/thread/682744

    private var methodChannel: FlutterMethodChannel
    private var serviceBrowsers: [String: NetServiceBrowser] = [:]
    private var services: [String: NetService] = [:]

    init(methodChannel: FlutterMethodChannel) {
        self.methodChannel = methodChannel
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = NsdIosPlugin(methodChannel: methodChannel)
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }

    public func handle(_ methodCall: FlutterMethodCall, result: @escaping FlutterResult) {

        switch methodCall.method {

        case "startDiscovery":
            startDiscovery(methodCall.arguments, result)

        case "stopDiscovery":
            stopDiscovery(methodCall.arguments, result)

        case "register":
            register(methodCall.arguments, result)

        case "resolve":
            resolve(methodCall.arguments, result)

        case "unregister":
            unregister(methodCall.arguments, result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startDiscovery(_ arguments: Any?, _ result: FlutterResult) {

        guard let agentId = deserializeAgentId(arguments) else {
            result(FlutterError(code: ErrorCause.illegalArgument.code, message: "Agent ID cannot be null", details: nil))
            return
        }

        guard let serviceType = deserializeServiceType(arguments) else {
            result(FlutterError(code: ErrorCause.illegalArgument.code, message: "Service type cannot be null", details: nil))
            return
        }

        let serviceBrowser = NetServiceBrowser()
        serviceBrowser.delegate = self
        serviceBrowsers[agentId] = serviceBrowser // set before invoking search so that callback methods can access it
        serviceBrowser.searchForServices(ofType: serviceType, inDomain: "local.")
        result(nil)
    }

    private func stopDiscovery(_ arguments: Any?, _ result: FlutterResult) {
        guard let agentId = deserializeAgentId(arguments) else {
            result(FlutterError(code: ErrorCause.illegalArgument.code, message: "Agent ID cannot be null", details: nil))
            return
        }

        guard let serviceBrowser = serviceBrowsers[agentId] else {
            result(FlutterError(code: ErrorCause.illegalArgument.code, message: "Unknown agent ID: \(agentId)", details: nil))
            return
        }

        serviceBrowser.stop()
        result(nil)
    }

    private func resolve(_ arguments: Any?, _ result: FlutterResult) {
        guard let agentId = deserializeAgentId(arguments) else {
            result(FlutterError(code: ErrorCause.illegalArgument.code, message: "Agent ID cannot be null", details: nil))
            return
        }

        guard let service = deserializeServiceInfo(arguments) else {
            result(FlutterError(code: ErrorCause.illegalArgument.code, message: "Invalid service info", details: nil))
            return
        }

        service.delegate = self
        services[agentId] = service // set before invoking search so that callback methods can access it
        service.resolve(withTimeout: 10)
        result(nil)
    }

    private func register(_ arguments: Any?, _ result: FlutterResult) {
        guard let agentId = deserializeAgentId(arguments) else {
            result(FlutterError(code: ErrorCause.illegalArgument.code, message: "Agent ID cannot be null", details: nil))
            return
        }

        guard let service = deserializeServiceInfo(arguments) else {
            result(FlutterError(code: ErrorCause.illegalArgument.code, message: "Invalid service info", details: nil))
            return
        }

        service.delegate = self
        services[agentId] = service // set before invoking search so that callback methods can access it
        service.publish(options: [.listenForConnections])
        result(nil)
    }

    private func unregister(_ arguments: Any?, _ result: FlutterResult) {
        guard let agentId = deserializeAgentId(arguments) else {
            result(FlutterError(code: ErrorCause.illegalArgument.code, message: "Agent ID cannot be null", details: nil))
            return
        }

        let service: NetService? = services[agentId];
        service?.stop();
        result(nil);
    }

    public func netServiceBrowserWillSearch(_ serviceBrowser: NetServiceBrowser) {
        guard let agentId = getAgentId(serviceBrowser) else {
            return
        }

        methodChannel.invokeMethod("onDiscoveryStartSuccessful", arguments: serializeAgentId(agentId))
    }

    public func netServiceBrowser(_ serviceBrowser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        guard let agentId = getAgentId(serviceBrowser) else {
            return
        }

        methodChannel.invokeMethod("onDiscoveryStartFailed", arguments: serializeAgentId(agentId))
        serviceBrowser.delegate = nil
        serviceBrowsers[agentId] = nil
    }

    public func netServiceBrowserDidStopSearch(_ serviceBrowser: NetServiceBrowser) {
        guard let agentId = getAgentId(serviceBrowser) else {
            return
        }

        methodChannel.invokeMethod("onDiscoveryStopSuccessful", arguments: serializeAgentId(agentId))
        serviceBrowser.delegate = nil
        serviceBrowsers[agentId] = nil
    }

    public func netServiceBrowser(_ serviceBrowser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard let agentId = getAgentId(serviceBrowser) else {
            return
        }

        let arguments = serializeAgentId(agentId).merging(serializeServiceInfo(service))
        methodChannel.invokeMethod("onServiceDiscovered", arguments: arguments)
    }

    public func netServiceBrowser(_ serviceBrowser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        guard let agentId = getAgentId(serviceBrowser) else {
            return
        }

        let arguments = serializeAgentId(agentId).merging(serializeServiceInfo(service))
        methodChannel.invokeMethod("onServiceLost", arguments: arguments)
    }

    public func netServiceDidPublish(_ service: NetService) {
        guard let agentId = getAgentId(service) else {
            return
        }

        let arguments = serializeAgentId(agentId).merging(serializeServiceInfo(service))
        methodChannel.invokeMethod("onRegistrationSuccessful", arguments: arguments)
    }

    public func netService(_ service: NetService, didNotPublish errorDict: [String: NSNumber]) {
        guard let agentId = getAgentId(service) else {
            return
        }

        let errorCode = getErrorCode(errorDict["NSNetServicesErrorCode"])

        let arguments = serializeAgentId(agentId)
                .merging(serializeErrorCause(getErrorCause(errorCode)))
                .merging(serializeErrorMessage(getErrorMessage(errorCode)))
        methodChannel.invokeMethod("onRegistrationFailed", arguments: arguments)
    }

    public func netServiceDidStop(_ service: NetService) {
        guard let agentId = getAgentId(service) else {
            return
        }

        service.delegate = nil
        services[agentId] = nil

        methodChannel.invokeMethod("onUnregistrationSuccessful", arguments: serializeAgentId(agentId))
    }

    public func netServiceDidResolveAddress(_ service: NetService) {
        guard let agentId = getAgentId(service) else {
            return
        }

        service.delegate = nil
        services[agentId] = nil

        let arguments = serializeAgentId(agentId).merging(serializeServiceInfo(service))
        methodChannel.invokeMethod("onResolveSuccessful", arguments: arguments)
    }

    public func netServiceDidNotResolve(_ service: NetService, didNotResolve errorDict: [String: NSNumber]) {
        guard let agentId = getAgentId(service) else {
            return
        }

        service.delegate = nil
        services[agentId] = nil

        let errorCode = getErrorCode(errorDict["NSNetServicesErrorCode"])

        let arguments = serializeAgentId(agentId)
                .merging(serializeErrorCause(getErrorCause(errorCode)))
                .merging(serializeErrorMessage(getErrorMessage(errorCode)))
        methodChannel.invokeMethod("onResolveFailed", arguments: arguments)
    }

    private func getAgentId(_ serviceBrowser: NetServiceBrowser) -> String? {
        serviceBrowsers.first(where: { $1 === serviceBrowser })?.key
    }

    private func getAgentId(_ service: NetService) -> String? {
        services.first(where: { $1 === service })?.key
    }
}

extension Dictionary {
    func merging(_ item: [Key: Value]) -> [Key: Value] {
        merging(item) { (a, b) in
            b
        }
    }
}
