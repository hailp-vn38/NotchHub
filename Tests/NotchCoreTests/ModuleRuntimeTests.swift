import NotchCore
import NotchDemoModule
import NotchDomain
import Testing

@Test("Module runtime starts an enabled module through its public health seam")
func startsEnabledModule() async throws {
    let module = RecordingModule(id: try #require(ModuleID("test.module")))
    let runtime = ModuleRuntime()

    await runtime.register(module, enabled: true)
    await runtime.start(module.id)

    let health = try #require(await runtime.health(for: module.id))
    #expect(health.state == .running)
    #expect(await module.startCount == 1)
}

@Test("DemoModule keeps descriptors and resources bounded across 100 enable cycles")
func demoModuleCleansUpAcrossRepeatedCycles() async throws {
    let module = NotchDemoModule()
    let runtime = ModuleRuntime()
    await runtime.register(module, enabled: true)
    for _ in 0..<100 {
        await runtime.start(module.id)
        #expect(await runtime.contributions(for: module.id).map(\.slot) == [.indicator, .compactStatus])
        await runtime.setEnabled(false, for: module.id)
        #expect(await runtime.activeResourceCount(for: module.id) == 0)
        await runtime.setEnabled(true, for: module.id)
    }
}

@Test("DemoModule exposes ping only while its lifetime is running")
func demoPingIsRevokedOnDisable() async throws {
    let events = RecordingModuleEventPublisher()
    let runtime = ModuleRuntime(eventPublisher: events)
    let module = NotchDemoModule()
    await runtime.register(module, enabled: true)
    await runtime.start(module.id)
    let ping = try #require(ActionID("demo.ping"))

    #expect(await runtime.actions.definitions().map(\.id) == [ping])
    await runtime.actions.invoke(ping)
    #expect(await events.events.contains(.init(moduleID: module.id, type: EventType("demo.tick")!)))
    await runtime.setEnabled(false, for: module.id)
    #expect(await runtime.actions.definitions().isEmpty)
}

@Test("Disabling a running module revokes its lifetime and persists stopped intent")
func disablingModuleStopsAndRevokesResources() async throws {
    let module = RecordingModule(id: try #require(ModuleID("test.module")))
    let runtime = ModuleRuntime()
    await runtime.register(module, enabled: true)
    await runtime.start(module.id)

    await runtime.setEnabled(false, for: module.id)

    let health = try #require(await runtime.health(for: module.id))
    #expect(health.state == .stopped)
    #expect(!health.isEnabled)
    #expect(await module.stopCount == 1)
    #expect(await runtime.activeResourceCount(for: module.id) == 0)
}

private actor RecordingModule: NotchModule {
    nonisolated let id: ModuleID
    nonisolated let metadata = ModuleMetadata(displayName: "Test")
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(id: ModuleID) { self.id = id }

    func start(context: ModuleContext) async throws {
        startCount += 1
        await context.lifetime.register(.task, named: "work")
    }

    func stop() async { stopCount += 1 }

    func handle(_: ModuleCommand) async throws -> ModuleCommandResult { .ignored }
}
