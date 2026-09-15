import NotchCore
import NotchDomain

public actor NotchDemoModule: NotchModule {
    public nonisolated let id = ModuleID("demo")!
    public nonisolated let metadata = ModuleMetadata(
        displayName: "Demo Module", version: "1.0.0",
        supportedSurfaceSlots: [.indicator, .compactStatus])

    public init() {}

    public func start(context: ModuleContext) async throws {
        await context.lifetime.register(.task, named: "demo.tick")
        await context.lifetime.register(.init(moduleID: id, slot: .indicator, text: "Demo"))
        await context.lifetime.register(.init(moduleID: id, slot: .compactStatus, text: "Demo ready"))
        let ping = ModuleAction(
            definition: .init(id: ActionID("demo.ping")!, title: "Demo ping"),
            invoke: { [eventPublisher = context.eventPublisher, id] in
                await eventPublisher.publish(.init(moduleID: id, type: EventType("demo.tick")!))
            })
        _ = await context.actions.register(ping, lifetime: context.lifetime)
    }

    public func stop() async {}
    public func handle(_ command: ModuleCommand) async throws -> ModuleCommandResult {
        if case .simulateFailure = command { throw DemoError.simulated }
        return .ignored
    }
}

public enum DemoError: Error, Sendable { case simulated }
