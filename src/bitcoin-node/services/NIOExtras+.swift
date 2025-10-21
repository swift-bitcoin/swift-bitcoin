import NIOExtras
import NIOCore
import Logging

extension DebugInboundEventsHandler {
    convenience init(logger: Logger) {
        self.init { event, context in
            let message = switch event {
            case .registered: "Channel registered"
            case .unregistered: "Channel unregistered"
            case .active: "Channel became active"
            case .inactive: "Channel became inactive"
            case .read(let data): "Channel read \(data)"
            case .readComplete: "Channel completed reading"
            case .writabilityChanged(let isWritable): "Channel writability changed to \(isWritable)"
            case .userInboundEventTriggered(let event): "Channel user inbound event \(event) triggered"
            case .errorCaught(let error): "Channel caught error: \(error)"
            }
            logger.debug("\(message) in \(context.name)")
        }
    }
}

extension DebugOutboundEventsHandler {
    convenience init(logger: Logger) {
        self.init { event, context in
            let message = switch event {
            case .register: "Registering channel"
            case .bind(let address): "Binding to \(address)"
            case .connect(let address): "Connecting to \(address)"
            case .write(let data): "Writing \(data)"
            case .flush: "Flushing"
            case .read: "Reading"
            case .close(let mode): "Closing with mode \(mode)"
            case .triggerUserOutboundEvent(let event): "Triggering user outbound event: { \(event) }"
            }
            logger.debug("\(message) in \(context.name)")
        }
    }
}
