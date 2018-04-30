
import LLVM

extension builtin {

    enum platform {

        static var pointerWidth: BuiltinEntity = BuiltinEntity(
            name: "PointerWidth",
            constant: UInt64(targetMachine.dataLayout.pointerSize()),
            type: ty.i64
        ) { g in
            var val = g.word.constant(targetMachine.dataLayout.pointerSize() * 8)

            var global = g.addOrReuseGlobal(".platform.PointerWidth", initializer: val)
            global.linkage = .private
            return global
        }

        static var isBigEndian: BuiltinEntity = BuiltinEntity(
            name: "IsBigEndian",
            constant: (targetMachine.dataLayout.byteOrder == .bigEndian ? 1 : 0) as UInt64,
            type: ty.bool
        ) { g in
            let val = g.i1.constant(targetMachine.dataLayout.byteOrder == .bigEndian ? 1 : 0)

            var global = g.addOrReuseGlobal(".platform.IsBigEndian", initializer: val)
            global.linkage = .private
            return global
        }

        static var osTriple: BuiltinEntity = BuiltinEntity(
            name: "OSTriple",
            constant: targetMachine.triple,
            type: ty.string
        ) { g in
            let val = g.emit(constantString: targetMachine.triple)

            var global = g.addOrReuseGlobal(".platform.OSTriple", initializer: val)
            global.linkage = .private
            return global
        }
    }
}
