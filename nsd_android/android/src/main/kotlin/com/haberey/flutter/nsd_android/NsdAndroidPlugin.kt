package com.haberey.flutter.nsd_android

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
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
    private lateinit var wifiManager: WifiManager
    private lateinit var methodChannel: MethodChannel

    private var multicastLock: WifiManager.MulticastLock? = null

    private val discoveryListeners = HashMap<String, NsdManager.DiscoveryListener>()
    private val resolveListeners = HashMap<String, NsdManager.ResolveListener>()
    private val registrationListeners = HashMap<String, NsdManager.RegistrationListener>()

    private val resolveSemaphore = Semaphore(1)

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val context = flutterPluginBinding.applicationContext

        nsdManager = getSystemService(context, NsdManager::class.java)!!
        wifiManager = getSystemService(context, WifiManager::class.java)!!

        if (multicastPermissionGranted(context)) {
            multicastLock = wifiManager.createMulticastLock("nsdMulticastLock").also {
                it.setReferenceCounted(true)
            }
        }

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

        val handle = deserializeHandle(methodCall.arguments()) ?: throw NsdError(
            ErrorCause.ILLEGAL_ARGUMENT,
            "Cannot start discovery: expected handle"
        )

        if (multicastLock == null) {
            throw NsdError(
                ErrorCause.SECURITY_ISSUE,
                "Missing required permission CHANGE_WIFI_MULTICAST_STATE"
            )
        }

        multicastLock?.acquire()

        try {

            val discoveryListener = createDiscoveryListener(handle)
            discoveryListeners[handle] = discoveryListener

            nsdManager.discoverServices(
                serviceType,
                NsdManager.PROTOCOL_DNS_SD,
                discoveryListener
            )

            result.success(null)

        } catch (e: Throwable) {
            multicastLock?.release()
            throw e
        }

    }

    private fun stopDiscovery(methodCall: MethodCall, result: Result) {
        val handle = deserializeHandle(methodCall.arguments()) ?: throw NsdError(
            ErrorCause.ILLEGAL_ARGUMENT,
            "Cannot stop discovery: expected handle"
        )

        if (multicastLock == null) {
            throw NsdError(
                ErrorCause.SECURITY_ISSUE,
                "Missing required permission CHANGE_WIFI_MULTICAST_STATE"
            )
        }

        multicastLock?.release()

        nsdManager.stopServiceDiscovery(discoveryListeners[handle])
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

        val handle = deserializeHandle(methodCall.arguments()) ?: throw NsdError(
            ErrorCause.ILLEGAL_ARGUMENT,
            "Cannot register service: expected handle"
        )

        val registrationListener = createRegistrationListener(handle)
        registrationListeners[handle] = registrationListener

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

        val handle = deserializeHandle(methodCall.arguments()) ?: throw NsdError(
            ErrorCause.ILLEGAL_ARGUMENT,
            "Cannot resolve service: expected handle"
        )

        val resolveListener = createResolveListener(handle)
        resolveListeners[handle] = resolveListener

        result.success(null)

        thread {
            resolveSemaphore.acquire()
            nsdManager.resolveService(serviceInfo, resolveListener)
        }
    }

    private fun unregister(methodCall: MethodCall, result: Result) {
        val handle = deserializeHandle(methodCall.arguments()) ?: throw NsdError(
            ErrorCause.ILLEGAL_ARGUMENT,
            "Cannot unregister service: handle expected"
        )

        val registrationListener = registrationListeners[handle]
        nsdManager.unregisterService(registrationListener)

        result.success(null)
    }

    // NsdManager requires one listener instance per discovery
    private fun createDiscoveryListener(handle: String) =
        object : NsdManager.DiscoveryListener {

            val serviceInfos = ArrayList<NsdServiceInfo>()

            override fun onDiscoveryStarted(serviceType: String) {
                invokeMethod("onDiscoveryStartSuccessful", serializeHandle(handle))
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                discoveryListeners.remove(handle)
                val arguments = serializeHandle(handle) +
                        serializeErrorCause(getErrorCause(errorCode)) +
                        serializeErrorMessage(getErrorMessage(errorCode))
                invokeMethod("onDiscoveryStartFailed", arguments)
            }

            override fun onDiscoveryStopped(serviceType: String) {
                discoveryListeners.remove(handle)
                invokeMethod("onDiscoveryStopSuccessful", serializeHandle(handle))
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                discoveryListeners.remove(handle)
                val arguments = serializeHandle(handle) +
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
                    val arguments = serializeHandle(handle) + serializeServiceInfo(serviceInfo)
                    invokeMethod("onServiceDiscovered", arguments)
                }
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                val existingServiceInfo = serviceInfos.find { isSameService(it, serviceInfo) }
                if (existingServiceInfo != null) {
                    serviceInfos.remove(existingServiceInfo)
                    val arguments =
                        serializeHandle(handle) + serializeServiceInfo(existingServiceInfo)
                    invokeMethod("onServiceLost", arguments)
                }
            }
        }

    private fun isSameService(a: NsdServiceInfo, b: NsdServiceInfo): Boolean {
        return (a.serviceName == b.serviceName) && (a.serviceType == b.serviceType)
    }

    private fun createResolveListener(handle: String) =
        object : NsdManager.ResolveListener {
            override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                resolveListeners.remove(handle)
                val arguments = serializeHandle(handle) + serializeServiceInfo(serviceInfo)
                resolveSemaphore.release()
                invokeMethod("onResolveSuccessful", arguments)
            }

            override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                val arguments = serializeHandle(handle) +
                        serializeErrorCause(getErrorCause(errorCode)) +
                        serializeErrorMessage(getErrorMessage(errorCode))
                resolveListeners.remove(handle)
                resolveSemaphore.release()
                invokeMethod("onResolveFailed", arguments)
            }
        }

    private fun createRegistrationListener(handle: String) =
        object : NsdManager.RegistrationListener {

            override fun onServiceRegistered(registeredServiceInfo: NsdServiceInfo) {
                val arguments =
                    serializeHandle(handle) + serializeServiceName(registeredServiceInfo.serviceName)
                invokeMethod("onRegistrationSuccessful", arguments)
            }

            override fun onRegistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                registrationListeners.remove(handle)
                val arguments = serializeHandle(handle) +
                        serializeErrorCause(getErrorCause(errorCode)) +
                        serializeErrorMessage(getErrorMessage(errorCode))
                invokeMethod("onRegistrationFailed", arguments)
            }

            override fun onServiceUnregistered(serviceInfo: NsdServiceInfo) {
                registrationListeners.remove(handle)
                invokeMethod("onUnregistrationSuccessful", serializeHandle(handle))
            }

            override fun onUnregistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                registrationListeners.remove(handle)
                val arguments = serializeHandle(handle) +
                        serializeErrorCause(getErrorCause(errorCode)) +
                        serializeErrorMessage(getErrorMessage(errorCode))
                invokeMethod("onUnregistrationFailed", arguments)
            }
        }

    private fun invokeMethod(method: String, arguments: Any?) {
        Handler(Looper.getMainLooper()).post {
            methodChannel.invokeMethod(method, arguments)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        registrationListeners.forEach {
            nsdManager.unregisterService(it.value)
        }
    }

    private fun multicastPermissionGranted(context: Context) =
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CHANGE_WIFI_MULTICAST_STATE
        ) == PackageManager.PERMISSION_GRANTED
}
