import React
import LDSwiftEventSource

@objc(EventSource)
class EventSource: NSObject {
    private var _connected: Bool = false
    private var _eventsource: LDSwiftEventSource.EventSource?
    
    @objc(connect:options:)
    func connect(url: String, options: NSObject) -> Void {
        if (self._connected) {
            self.disconnect()
        }
        
        self._connected = true
        
        let config = EventConfigBuilder().build(url: url, options: options)

        self._eventsource = LDSwiftEventSource.EventSource(config: config)
        
        self._eventsource?.start()
        
//        let semaphore = DispatchSemaphore(value: 0)
//        let runLoop = RunLoop.current
//        while semaphore.wait(timeout: .now()) == .timedOut {
//            runLoop.run(mode: .default, before: .distantFuture)
//        }
    }
    
    @objc(disconnect)
    func disconnect() -> Void {
        self._connected = false
        self._eventsource?.stop()
    }
}

class EventConfigBuilder {
    public func build(url: String, options: NSObject) -> LDSwiftEventSource.EventSource.Config {
        let method = (options.value(forKey: "method") as? String) ?? "GET"
        let body = (options.value(forKey: "body") as? Dictionary) ?? Dictionary<String, String>()
        
        var config = LDSwiftEventSource.EventSource.Config(
            handler: EventHandler(),
            url: URL(string: url)!
        );
        
        config.method = method
        config.headers = options.value(forKey: "headers") as? Dictionary ?? Dictionary<String, String>()
        config.lastEventId = options.value(forKey: "lastEventId") as? String ?? ""
        
        config.reconnectTime = 300000000
        config.maxReconnectTime = 300000000
        
        config.idleTimeout = 60
        
        if (method == "POST") {
            config.body = try? JSONSerialization.data(withJSONObject: body)
        }
        
        return config;
    }
}

//class ConnectionErrorHandler {
//    func handler(error: Error) -> LDSwiftEventSource.ConnectionErrorAction {
//        guard let unsuccessfulResponseError = error as? UnsuccessfulResponseError else { return .proceed }
//
//        let responseCode: Int = unsuccessfulResponseError.responseCode
//        if 204 == responseCode {
//            return .shutdown
//        }
//        return .proceed
//    }
//}

class EventHandler: LDSwiftEventSource.EventHandler
{
    func sendEvent(event: EventType, data: Dictionary<String, String>) {
        var body = ["type": event.rawValue];
        body.merge(data) { (_, new) in new }
        RNEventEmitter.emitter.sendEvent(withName: event.rawValue, body: body )
    }
    
    func onOpened() {
        self.sendEvent(event: EventType.OPEN, data: [:])
    }

    func onClosed() {
        self.sendEvent(event: EventType.CLOSE, data: [:])
    }

    func onMessage(eventType: String, messageEvent: MessageEvent) {
        print(eventType,messageEvent)
        self.sendEvent(event: EventType.MESSAGE, data: ["data": messageEvent.data, "lastEventId": messageEvent.lastEventId, "event": eventType])
    }

    func onComment(comment: String) {
        print("comment", comment)
        // FIXME: add comment event when needed
    }

    func onError(error: Error) {
        print("[rnsse] error")
        guard let unsuccessfulResponseError = error as? UnsuccessfulResponseError else {
            return
        }
        
        guard let data = unsuccessfulResponseError.response.url?.dataRepresentation as Data? else {
            print("no data")
            return
        }
        
        
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] {
            print("json", json)
        }
        
        print("no json", data)
        
        // TODO: api error
        self.sendEvent(event: EventType.ERROR, data: [:])
    }
}

public enum EventType: String, CaseIterable {
    case OPEN = "open"
    case CLOSE = "close"
    case MESSAGE = "message"
    case ERROR = "error"
    case TIMEOUT = "timeout"
}

@objc(RNEventEmitter)
open class RNEventEmitter: RCTEventEmitter {
    
    public static var emitter: RCTEventEmitter!
    
    override init() {
        super.init()
        RNEventEmitter.emitter = self
    }
    
    open override func supportedEvents() -> [String] {
        return EventType.allCases.map { $0.rawValue }
    }
}