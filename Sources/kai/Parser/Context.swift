
extension Parser {

  class Context {

    var parent: Context? = nil

    var state: State = .global

    enum State {
      case global

      case procedureBody
      case structureBody
      case enumerationBody

      case procedureCall
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
