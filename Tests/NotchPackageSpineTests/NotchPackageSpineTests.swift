import NotchDomain
import Testing

@Test("The root package exposes the NotchDomain boundary")
func exposesNotchDomainBoundary() {
    _ = NotchDomainPackage.self
}
