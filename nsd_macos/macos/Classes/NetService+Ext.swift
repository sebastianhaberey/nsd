import Foundation
import Network

extension NetService {

    public var displayString: String {
        //        return "NetService(name:\(name), ips:\(ipAddresses), port:\(port), type: \(type), domain:\(domain), hostName:\(hostName ?? "nil"))"
        return "NetService(name:\(name), ips:\(ipAddresses), port:\(port), hostName:\(hostName ?? "nil"))"
    }

    @available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
    public var ipAddresses: [IPAddress] {
        guard let addresses = addresses else {
            return []
        }
        var ipAddrs = [IPAddress]()
        for sockAddrData in addresses {
            if sockAddrData.count == MemoryLayout<sockaddr_in>.size {
                let sockAddrBytes = UnsafeMutableBufferPointer<sockaddr_in>.allocate(capacity: sockAddrData.count)
                assert(sockAddrData.copyBytes(to: sockAddrBytes) == MemoryLayout<sockaddr_in>.size)
                if var sinAddr = sockAddrBytes.baseAddress?.pointee.sin_addr,
                   let ipAddr = IPv4Address(Data(bytes: &sinAddr.s_addr, count: MemoryLayout<in_addr>.size)) {
                    ipAddrs.append(ipAddr)
                }
            } else if sockAddrData.count == MemoryLayout<sockaddr_in6>.size {
                let sockAddrBytes = UnsafeMutableBufferPointer<sockaddr_in6>.allocate(capacity: sockAddrData.count)
                assert(sockAddrData.copyBytes(to: sockAddrBytes) == MemoryLayout<sockaddr_in6>.size)
                if var sinAddr = sockAddrBytes.baseAddress?.pointee.sin6_addr,
                   let ipAddr = IPv6Address(Data(bytes: &sinAddr, count: MemoryLayout<in6_addr>.size)) {
                    ipAddrs.append(ipAddr)
                }
            }
        }
        return ipAddrs
    }
}

extension IPAddress {
    var ipString: String {
        String(describing: self)
    }
}
