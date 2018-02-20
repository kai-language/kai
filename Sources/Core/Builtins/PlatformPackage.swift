
import LLVM

extension builtin {

    enum platform {

        static var pointerWidth: BuiltinEntity = BuiltinEntity(name: "PointerWidth", type: ty.i64) { g in
            var val = g.i64.constant(targetMachine.dataLayout.pointerSize() * 8)

            var global = g.addOrReuseGlobal(named: ".platform.PointerWidth", initializer: val)
            global.linkage = .private
            return global
        }

        static var isBigEndian: BuiltinEntity = BuiltinEntity(name: "IsBigEndian", type: ty.bool) { g in
            let val = g.i1.constant(targetMachine.dataLayout.byteOrder == .bigEndian ? 1 : 0)

            var global = g.addOrReuseGlobal(named: ".platform.IsBigEndian", initializer: val)
            global.linkage = .private
            return global
        }

        static var osTriple: BuiltinEntity = BuiltinEntity(name: "OSTriple", type: ty.string) { g in
            let val = g.emit(constantString: targetMachine.triple)

            var global = g.addOrReuseGlobal(named: ".platform.OSTriple", initializer: val)
            global.linkage = .private
            return global
        }

    }
}
