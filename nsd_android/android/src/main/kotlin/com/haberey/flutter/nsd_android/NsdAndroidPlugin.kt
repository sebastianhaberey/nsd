package com.haberey.flutter.nsd_android

import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat.getSystemService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Semaphore
import kotlin.collections.HashMap
import kotlin.concurrent.thread

private const val CHANNEL_NAME = "com.haberey/nsd"

class NsdAndroidPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var nsdManager: NsdManager
    private lateinit var methodChannel: MethodChannel

    private val discoveryListeners = HashMap<String, NsdManager.DiscoveryListener>()
    private val resolveListeners = HashMap<String, NsdManager.ResolveListener>()
    private val registrationListeners = HashMap<String, NsdManager.RegistrationListener>()

    private val resolveSemaphore = Semaphore(1)

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        nsdManager =
            getSystemService(flutterPluginBinding.applicationContext, NsdManager::class.java)!!
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull methodCall: MethodCall, @NonNull result: Result) {
        val method = methodCall.method
        try {
            when (method) {
                "startDiscovery" -> startDiscovery(methodCall, result)
                "stopDiscovery" -> stopDiscovery(methodCall, result)
                "resolve" -> resolve(methodCall, result)
                "register" -> register(methodCall, result)
                "unregister" -> unregister(methodCall, result)
                else -> result.notImplemented()
            }
        } catch (e: NsdError) {
            result.error(e.errorCause.code, e.errorMessage, null)
        } catch (e: Exception) {
            result.error(
                ErrorCause.INTERNAL_ERROR.code,
                "$method: ${e.message}",
                null
            )
        }
    }

    private fun startDiscovery(methodCall: MethodCall, result: Result) {
        val serviceType = deserializeServiceType(methodCall.arguments())
            ?: throw NsdError(
                ErrorCause.ILLEGAL_ARGUMENT,
                "Cannot start discovery: expected service type"
            )

        val agentId = deserializeAgentId(methodCall.arguments()) ?: throw NsdError(
            ErrorCause.ILLEGAL_ARGUMENT,
            "Cannot start discovery: expected agent id"
        )

        val discoveryListener = createDiscoveryListener(agentId)
        discoveryListeners[agentId] = discoveryListener

        nsdManager.discoverServices(
            serviceType,
            NsdManager.PROTOCOL_DNS_SD,
            discoveryListener
        )

        result.success(null)
    }

    private fun stopDiscovery(methodCall: MethodCall, result: Result) {
        val agentId = deserializeAgentId(methodCall.arguments()) ?: throw NsdError(
            ErrorCause.ILLEGAL_ARGUMENT,
            "Cannot stop discovery: expected agent id"
        )

        nsdManager.stopServiceDiscovery(discoveryListeners[agentId])
        result.success(null)
    }

    private fun register(methodCall: MethodCall, result: Result) {
        val serviceInfo = deserializeServiceInfo(methodCall.arguments())
        if (serviceInfo == null || serviceInfo.serviceName == null || serviceInfo.serviceType == null || serviceInfo.port == 0) {
            throw NsdError(
                ErrorCause.ILLEGAL_ARGUMENT,
                "Cannot register service: expected service info with service name, type and port"
            )
        }

        val agentId = deserializeAgentId(methodCall.arguments()) ?: throw NsdError(
            ErrorCause.ILLEGAL_ARGUMENT,
            "Cannot register service: expected agent id"
        )

        val registrationListener = createRegistrationListener(agentId)
        registrationListeners[agentId] = registrationListener

        nsdManager.registerService(
            serviceInfo, NsdManager.PROTOCOL_DNS_SD, registrationListener
        )

        result.success(null)
    }

    private fun resolve(methodCall: MethodCall, result: Result) {
        val serviceInfo = deserializeServiceInfo(methodCall.arguments())
        if (serviceInfo == null || serviceInfo.serviceName == null || serviceInfo.serviceType == null) {
            throw NsdError(
                ErrorCause.ILLEGAL_ARGUMENT,
                "Cannot resolve service: expected service info with service name, type"
            )
        }

        val agentId = deserializeAgentId(methodCall.arguments()) ?: throw NsdError(
            ErrorCause.ILLEGAL_ARGUMENT,
            "Cannot resolve service: expected agent id"
        )

        val resolveListener = createResolveListener(agentId)
        resolveListeners[agentId] = resolveListener

        result.success(null)

        thread {
            resolveSemaphore.acquire()
            nsdManager.resolveService(serviceInfo, resolveListener)
        }
    }

    private fun unregister(methodCall: MethodCall, result: Result) {
        val agentId = deserializeAgentId(methodCall.arguments()) ?: throw NsdError(
            ErrorCause.ILLEGAL_ARGUMENT,
            "Cannot unregister service: agent id expected"
        )

        val registrationListener = registrationListeners[agentId]
        nsdManager.unregisterService(registrationListener)

        result.success(null)
    }

    // NsdManager requires one listener instance per discovery
    private fun createDiscoveryListener(agentId: String) =
        object : NsdManager.DiscoveryListener {

            val serviceInfos = ArrayList<NsdServiceInfo>()

            override fun onDiscoveryStarted(serviceType: String) {
                invokeMethod("onDiscoveryStartSuccessful", serializeAgentId(agentId))
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                discoveryListeners.remove(agentId)
                val arguments = serializeAgentId(agentId) +
                        serializeErrorCause(getErrorCause(errorCode)) +
                        serializeErrorMessage(getErrorMessage(errorCode))
                invokeMethod("onDiscoveryStartFailed", arguments)
            }

            override fun onDiscoveryStopped(serviceType: String) {
                discoveryListeners.remove(agentId)
                invokeMethod("onDiscoveryStopSuccessful", serializeAgentId(agentId))
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                discoveryListeners.remove(agentId)
                val arguments = serializeAgentId(agentId) +
                        serializeErrorCause(getErrorCause(errorCode)) +
                        serializeErrorMessage(getErrorMessage(errorCode))
                invokeMethod("onDiscoveryStopFailed", arguments)
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                // NsdManager finds services residing on the same machine multiple (3) times - most likely a bug.
                // The code example at https://developer.android.com/training/connect-devices-wirelessly/nsd
                // filters out any services on the same machine, but that won't suffice for all use cases.
                if (serviceInfos.none { isSameService(it, serviceInfo) }) {
                    serviceInfos.add(serviceInfo)
                    val arguments = serializeAgentId(agentId) + serializeServiceInfo(serviceInfo)
                    invokeMethod("onServiceDiscovered", arguments)
                }
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                val existingServiceInfo = serviceInfos.find { isSameService(it, serviceInfo) }
                if (existingServiceInfo != null) {
                    serviceInfos.remove(existingServiceInfo)
                    val arguments =
                        serializeAgentId(agentId) + serializeServiceInfo(existingServiceInfo)
                    invokeMethod("onServiceLost", arguments)
                }
            }
        }

    private fun isSameService(a: NsdServiceInfo, b: NsdServiceInfo): Boolean {
        return (a.serviceName == b.serviceName) && (a.serviceType == b.serviceType)
    }

    private fun createResolveListener(agentId: String) =
        object : NsdManager.ResolveListener {
            override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                resolveListeners.remove(agentId)
                val arguments = serializeAgentId(agentId) + serializeServiceInfo(serviceInfo)
                resolveSemaphore.release()
                invokeMethod("onResolveSuccessful", arguments)
            }

            override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                val arguments = serializeAgentId(agentId) +
                        serializeErrorCause(getErrorCause(errorCode)) +
                        serializeErrorMessage(getErrorMessage(errorCode))
                resolveListeners.remove(agentId)
                resolveSemaphore.release()
                invokeMethod("onResolveFailed", arguments)
            }
        }

    private fun createRegistrationListener(agentId: String) =
        object : NsdManager.RegistrationListener {

            override fun onServiceRegistered(registeredServiceInfo: NsdServiceInfo) {
                val arguments =
                    serializeAgentId(agentId) + serializeServiceName(registeredServiceInfo.serviceName)
                invokeMethod("onRegistrationSuccessful", arguments)
            }

            override fun onRegistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                registrationListeners.remove(agentId)
                val arguments = serializeAgentId(agentId) +
                        serializeErrorCause(getErrorCause(errorCode)) +
                        serializeErrorMessage(getErrorMessage(errorCode))
                invokeMethod("onRegistrationFailed", arguments)
            }

            override fun onServiceUnregistered(serviceInfo: NsdServiceInfo) {
                registrationListeners.remove(agentId)
                invokeMethod("onUnregistrationSuccessful", serializeAgentId(agentId))
            }

            override fun onUnregistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                registrationListeners.remove(agentId)
                val arguments = serializeAgentId(agentId) +
                        serializeErrorCause(getErrorCause(errorCode)) +
                        serializeErrorMessage(getErrorMessage(errorCode))
                invokeMethod("onUnregistratioFailed", arguments)
            }
        }

    private fun invokeMethod(method: String, arguments: Any?) {
        Handler(Looper.getMainLooper()).post {
            methodChannel.invokeMethod(method, arguments)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
    }
}
