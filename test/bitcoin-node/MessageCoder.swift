import Testing
import Foundation
import NIOCore
import NIOEmbedded
import BitcoinTransport
@testable import BitcoinNode

@Suite("MessageCoder integration with EmbeddedChannel")
struct MessageCoderTests {
    static func makeValidMessage(payload: Data = Data([1,2,3])) -> NetworkMessage {
        NetworkMessage(.version, payload: payload, magicBytes: 0xD9B4BEF9)
    }

    @Test("decode returns .needMoreData if not enough bytes")
    func decode_needMoreData() async throws {
        let channel = EmbeddedChannel()
        defer { _ = try? channel.finish() }
        try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(MessageCoder()))
        var buffer = channel.allocator.buffer(capacity: 4)
        buffer.writeBytes([0,1,2]) // Less than message base size
        try channel.writeInbound(buffer)
        let msg = try channel.readInbound(as: NetworkMessage.self)
        #expect(msg == nil)
    }

    @Test("decode decodes a valid message and fires it")
    func decode_validMessage() async throws {
        let msg = Self.makeValidMessage()
        let channel = EmbeddedChannel()
        defer { _ = try? channel.finish() }
        try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(MessageCoder()))
        var buffer = channel.allocator.buffer(capacity: msg.data.count)
        buffer.writeBytes(msg.data)
        try channel.writeInbound(buffer)
        let output = try channel.readInbound(as: NetworkMessage.self)
        #expect(output == msg)
    }

    @Test("encode outputs correct bytes for a message")
    func encode_message() async throws {
        let msg = Self.makeValidMessage()
        let channel = EmbeddedChannel()
        defer { _ = try? channel.finish() }
        try channel.pipeline.syncOperations.addHandler(MessageToByteHandler(MessageCoder()))
        try channel.writeOutbound(msg)
        var written = try channel.readOutbound(as: ByteBuffer.self)
        #expect(written?.readableBytes == msg.data.count)
        let bytes = written?.readBytes(length: msg.data.count)
        #expect(Data(bytes ?? []) == msg.data)
    }

    @Test("decode handles malformed message gracefully")
    func decode_malformedMessage() async throws {
        let msg = Self.makeValidMessage(payload: Data([1,2,3]))
        var data = msg.data
        data = data.dropLast(2) // Corrupt/truncate
        let channel = EmbeddedChannel()
        defer { _ = try? channel.finish() }
        try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(MessageCoder()))
        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        try channel.writeInbound(buffer)
        let output = try channel.readInbound(as: NetworkMessage.self)
        #expect(output == nil)
    }
}

