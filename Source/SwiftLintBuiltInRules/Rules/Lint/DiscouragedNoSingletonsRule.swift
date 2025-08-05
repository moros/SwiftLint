import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct DiscouragedNoSingletonsRule: Rule {
    // Opt-in rules still need a configuration; even if it's just severity.
    public var configuration = SeverityConfiguration<Self>(.warning)

    public init() {}

    public static let description: RuleDescription = .init(
        identifier: "discouraged_no_singletons",
        name: "Discourage Singletons",
        description: "Prefer dependency-injection over singletons",
        kind: .lint,
        nonTriggeringExamples: [
            Example("final class Foo { let bar = Bar() }")
        ],
        triggeringExamples: [
            Example("final class Foo { static let shared = Foo() }")
        ]
    )
}

// MARK: - Visitor

private extension DiscouragedNoSingletonsRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        private static let badNames: Set<String> = [
            "shared", "sharedInstance", "default", "standard", "current", "instance"
        ]

        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            /// Must be `static`
            guard node.modifiers.contains(keyword: .static) else {
                return .skipChildren // ✔︎ fixes “no member containsStatic”
            }

            // Identifier must look like a singleton
            guard
                let binding = node.bindings.first,
                let ident = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                Self.badNames.contains(ident)
            else { return .skipChildren }

            /// The rhs must instantiate *this* type (`Self()` / `Foo()` / `Module.Foo()`)
            guard
                let typeName = node.enclosingNominalName(), // helper below
                let rhs = binding.initializer?.value, // unwrap → Bool, not Bool?
                rhs.initializes(typeNamed: typeName)
            else { return .skipChildren }

            violations.append(node.positionAfterSkippingLeadingTrivia)
            return .skipChildren
        }
    }
}

// MARK: - Helper extensions

private extension SyntaxProtocol {
    /// Walks up the tree until it finds the surrounding `class / struct / enum / actor`
    /// and returns its identifier.
    func enclosingNominalName() -> String? {
        var current = parent
        while let node = current {
            if let cls = node.as(ClassDeclSyntax.self) { return cls.name.text }
            if let str = node.as(StructDeclSyntax.self) { return str.name.text }
            if let enm = node.as(EnumDeclSyntax.self) { return enm.name.text }
            if let act = node.as(ActorDeclSyntax.self) { return act.name.text }
            current = node.parent
        }
        return nil
    }
}

private extension ExprSyntax {
    /// Returns `true` for `Self()`, `Foo()`, or `Module.Foo()`.
    func initializes(typeNamed typeName: String) -> Bool {
        guard let call = self.as(FunctionCallExprSyntax.self) else { return false }

        /// a) `Self()`  →  DeclReferenceExprSyntax with baseName == "Self"
        if let ref = call.calledExpression.as(DeclReferenceExprSyntax.self),
           ref.baseName.text == "Self"
        {
            return true
        }

        /// b) `Foo()`
        if let ref = call.calledExpression.as(DeclReferenceExprSyntax.self),
           ref.baseName.text == typeName
        {
            return true
        }

        /// c) `Module.Foo()`
        if let mem = call.calledExpression.as(MemberAccessExprSyntax.self),
           mem.declName.baseName.text == typeName
        {
            return true
        }

        return false
    }
}
