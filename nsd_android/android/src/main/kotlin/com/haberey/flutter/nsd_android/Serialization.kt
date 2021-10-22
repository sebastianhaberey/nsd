package com.haberey.flutter.nsd_android

import android.net.nsd.NsdServiceInfo
import io.flutter.plugin.common.MethodCall
import java.net.InetAddress

private fun <T> serialize(key: String, value: T) = mapOf<String, Any?>(
    key to value
)

private fun <T> deserialize(methodCall: MethodCall, key: String): T? {
    return try {
        methodCall.argument<T>(key)
    } catch (e: Exception) {
        return null
    }
}

internal fun serializeErrorCause(errorCause: String) = serialize("error.cause", errorCause)

internal fun serializeErrorMessage(errorMessage: String) = serialize("error.message", errorMessage)

internal fun deserializeServiceType(methodCall: MethodCall): String? =
    deserialize<String>(methodCall, "service.type")

internal fun deserializeServiceInfo(methodCall: MethodCall): NsdServiceInfo? {

    val name = deserialize<String>(methodCall, "service.name")
    val type = deserializeServiceType(methodCall)
    val port = deserialize<Int>(methodCall, "service.port")

    // resolves to locallost if not set
    val host = InetAddress.getByName(deserialize<String>(methodCall, "service.host"))

    /// see below
    val txt = deserialize<Map<String, ByteArray>>(methodCall, "service.txt")

    if (name == null &&
        type == null &&
        host == null &&
        port == null &&
        txt == null
    ) {
        return null;
    }

    return NsdServiceInfo().apply {
        serviceName = name
        serviceType = type
        port?.let { setPort(port) }
        setHost(host)
        // TODO set txt: the specification allows bytes here but NsdManager only takes strings
    }
}

internal fun serializeServiceInfo(nsdServiceInfo: NsdServiceInfo): Map<String, Any?> {
    return serializeServiceInfo(
        name = nsdServiceInfo.serviceName,
        type = nsdServiceInfo.serviceType,
        host = nsdServiceInfo.host,
        port = nsdServiceInfo.port,
        txt = nsdServiceInfo.attributes
    )
}

internal fun serializeServiceInfo(
    name: String? = null,
    type: String? = null,
    host: InetAddress? = null,
    port: Int? = null,
    txt: Map<String, ByteArray>?
): Map<String, Any?> {
    return mapOf(
        "service.name" to name,
        "service.type" to cleanServiceType(type),
        "service.host" to host?.canonicalHostName,
        "service.port" to if (port == 0) null else port,
        "service.txt" to txt,
    )
}

fun cleanServiceType(serviceType: String?): String? {
    // In the specification http://files.dns-sd.org/draft-cheshire-dnsext-dns-sd.txt 4.1.2 / 7. it looks like
    // the dot doesn't actually belong to the <Service> portion but separates it from the domain portion.
    // The dot is removed here to allow unambiguous identification of services by their name / type combination.
    if (serviceType == null) {
        return serviceType
    }
    var out = serviceType
    if (out.isNotEmpty() && out.first() == '.') {
        out = out.drop(1)
    }
    if (out.isNotEmpty() && out.last() == '.') {
        out = out.dropLast(1)
    }
    return out;
}

internal fun serializeAgentId(agentId: String) = serialize("agentId", agentId)

internal fun deserializeAgentId(methodCall: MethodCall): String? =
    deserialize<String>(methodCall, "agentId")
