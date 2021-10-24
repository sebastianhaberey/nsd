package com.haberey.flutter.nsd_android

import org.junit.Test


internal class SerializationKtTest {

    @Test
    fun testDeserializeServiceInfo() {
        val arguments = hashMapOf<String, Any>(
            "service.txt" to hashMapOf<String, ByteArray?>(
                "attribute-a" to "κόσμε".toByteArray(Charsets.UTF_8)
            )
        )

        // TODO find a way to test it without NsdServiceInfo()
//        deserializeServiceInfo(arguments)
    }
}