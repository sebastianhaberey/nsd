package com.haberey.flutter.nsd_android

import android.net.nsd.NsdServiceInfo
import java.net.InetAddress
import java.nio.ByteBuffer
import java.nio.charset.CharsetDecoder
import java.nio.charset.CodingErrorAction

private enum class Key(val serializeKey: String) {
    HANDLE("handle"),
    SERVICE_NAME("service.name"),
    SERVICE_TYPE("service.type"),
    SERVICE_HOST("service.host"),
    SERVICE_PORT("service.port"),
    SERVICE_TXT("service.txt"),
    ERROR_CAUSE("error.cause"),
    ERROR_MESSAGE("error.message"),
}

val UTF8_DECODER = createUtf8Decoder()

internal fun serializeHandle(value: String?) = serialize(Key.HANDLE, value)

internal fun serializeServiceName(value: String?) = serialize(Key.SERVICE_NAME, value)

internal fun serializeErrorCause(value: String?) = serialize(Key.ERROR_CAUSE, value)

internal fun serializeErrorMessage(value: String?) =
    serialize(Key.ERROR_MESSAGE, value)

internal fun deserializeHandle(arguments: Map<String, Any?>?): String? =
    deserialize(Key.HANDLE, arguments)

internal fun deserializeServiceName(arguments: Map<String, Any?>?): String? =
    deserialize(Key.SERVICE_NAME, arguments)

internal fun deserializeServiceType(arguments: Map<String, Any?>?): String? =
    deserialize(Key.SERVICE_TYPE, arguments)

internal fun deserializeServiceHost(arguments: Map<String, Any?>?): String? =
    deserialize(Key.SERVICE_HOST, arguments)

internal fun deserializeServicePort(arguments: Map<String, Any?>?): Int? =
    deserialize(Key.SERVICE_PORT, arguments)

internal fun deserializeServiceTxt(arguments: Map<String, Any?>?): Map<String, ByteArray?>? =
    deserialize(Key.SERVICE_TXT, arguments)

internal fun deserializeServiceInfo(arguments: Map<String, Any?>?): NsdServiceInfo? {

    if (arguments == null) {
        return null
    }

    val name = deserializeServiceName(arguments)
    val type = deserializeServiceType(arguments)
    val port = deserializeServicePort(arguments)
    val host = deserializeServiceHost(arguments)
    val txt = deserializeServiceTxt(arguments)

    if (name == null &&
        type == null &&
        host == null &&
        port == null &&
        txt == null
    ) {
        return null
    }

    // If the host is null then an InetAddress representing an address of the loopback interface is returned.
    // https://docs.oracle.com/javase/7/docs/api/java/net/InetAddress.html#getByName(java.lang.String)
    val address = InetAddress.getByName(host)

    return NsdServiceInfo().apply {
        serviceName = name
        serviceType = type
        port?.let { setPort(port) }
        setHost(address)
        setAttributesFromTxt(txt)
    }
}

internal fun NsdServiceInfo.setAttributesFromTxt(flutterTxt: Map<String, ByteArray?>?) {
    flutterTxt?.let { txt ->
        txt.forEach {
            val key = it.key
            val value = it.value

            if (value == null) {
                setAttribute(key, null)
            } else {
                assertValidUtf8(key, value)
                setAttribute(key, value.toString(Charsets.UTF_8))
            }
        }
    }
}

private fun assertValidUtf8(key: String, value: ByteArray) {
    if (!isValidUtf8(value)) {
        throw NsdError(
            ErrorCause.ILLEGAL_ARGUMENT,
            "TXT value is not valid UTF8: $key: ${value.contentToString()}"
        )
    }
}

internal fun serializeServiceInfo(nsdServiceInfo: NsdServiceInfo): Map<String, Any?> {
    return mapOf(
        Key.SERVICE_NAME.serializeKey to nsdServiceInfo.serviceName,
        Key.SERVICE_TYPE.serializeKey to removeLeadingAndTrailingDots(serviceType = nsdServiceInfo.serviceType),
        Key.SERVICE_HOST.serializeKey to nsdServiceInfo.host?.canonicalHostName,
        Key.SERVICE_PORT.serializeKey to if (nsdServiceInfo.port == 0) null else nsdServiceInfo.port,
        Key.SERVICE_TXT.serializeKey to nsdServiceInfo.attributes,
    )
}

// In the specification http://files.dns-sd.org/draft-cheshire-dnsext-dns-sd.txt 4.1.2 / 7.
// it looks like leading and trailing dots do not belong to the <Service> portion but separate it
// from the surrounding <Name> and <Domain> portions. These dots are removed here to allow
// unambiguous identification of services by their name / type combination.
private fun removeLeadingAndTrailingDots(serviceType: String?): String? {

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

    return out
}

private inline fun <reified T> deserialize(key: Key, arguments: Map<String, Any?>?): T? =
    arguments?.get(key.serializeKey) as? T

private fun <T> serialize(key: Key, value: T?) = mapOf<String, Any?>(
    key.serializeKey to value
)

private fun isValidUtf8(value: ByteArray): Boolean = try {
    UTF8_DECODER.decode(ByteBuffer.wrap(value))
    true
} catch (e: CharacterCodingException) {
    false
}

private fun createUtf8Decoder(): CharsetDecoder = Charsets.UTF_8.newDecoder().apply {
    onMalformedInput(CodingErrorAction.REPORT)
    onUnmappableCharacter(CodingErrorAction.REPORT)
}