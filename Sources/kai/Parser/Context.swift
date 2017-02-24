
extension Parser {

    class Context {

        var parent: Context? = nil

        var state: State = .global

        var scope: Scope = .universal

        enum State {
            case global

            case procedureBody
            case structureBody
            case enumerationBody

            // allow keywords break & continue
            case loopBody

            case procedureCall
        }

        @discardableResult
        func pushNewScope() -> Scope {
            let newScope = Scope(parent: self.scope)
            self.scope = newScope

            return newScope
        }

        @discardableResult
        func popCurrentScope() -> Scope {
            guard let parent = self.scope.parent else {
                fatalError("Scope pop'd with no parent scope")
            }
            defer {
                self.scope = parent
            }

            return self.scope
        }
    }

    mutating func push(context state: Context.State) {
        let newContext = Context()
        newContext.parent = context
        newContext.state = state
        context = newContext
    }
    
    mutating func popContext() {
        context = context.parent!
    }
}
