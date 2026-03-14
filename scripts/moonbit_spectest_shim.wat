;; WASI shim for MoonBit's spectest::print_char
;; Enables running MoonBit wasm modules on wasmtime without moonrun
;; Usage: wasmtime --preload spectest=moonbit_spectest_shim.wat module.wasm
;;
;; MoonBit uses UTF-16 internally. For BMP characters (U+0000..U+FFFF),
;; print_char receives the codepoint directly. For supplementary characters
;; (U+10000+), it sends UTF-16 surrogate pairs (high then low).
(module
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory (export "memory") 1)

  ;; Store pending high surrogate (0 = none)
  (global $hi_surrogate (mut i32) (i32.const 0))

  (func $write_utf8 (param $cp i32)
    (local $len i32)
    (if (i32.le_u (local.get $cp) (i32.const 0x7F))
      (then
        (i32.store8 (i32.const 0) (local.get $cp))
        (local.set $len (i32.const 1)))
      (else (if (i32.le_u (local.get $cp) (i32.const 0x7FF))
        (then
          (i32.store8 (i32.const 0)
            (i32.or (i32.const 0xC0) (i32.shr_u (local.get $cp) (i32.const 6))))
          (i32.store8 (i32.const 1)
            (i32.or (i32.const 0x80) (i32.and (local.get $cp) (i32.const 0x3F))))
          (local.set $len (i32.const 2)))
        (else (if (i32.le_u (local.get $cp) (i32.const 0xFFFF))
          (then
            (i32.store8 (i32.const 0)
              (i32.or (i32.const 0xE0) (i32.shr_u (local.get $cp) (i32.const 12))))
            (i32.store8 (i32.const 1)
              (i32.or (i32.const 0x80) (i32.and (i32.shr_u (local.get $cp) (i32.const 6)) (i32.const 0x3F))))
            (i32.store8 (i32.const 2)
              (i32.or (i32.const 0x80) (i32.and (local.get $cp) (i32.const 0x3F))))
            (local.set $len (i32.const 3)))
          (else
            (i32.store8 (i32.const 0)
              (i32.or (i32.const 0xF0) (i32.shr_u (local.get $cp) (i32.const 18))))
            (i32.store8 (i32.const 1)
              (i32.or (i32.const 0x80) (i32.and (i32.shr_u (local.get $cp) (i32.const 12)) (i32.const 0x3F))))
            (i32.store8 (i32.const 2)
              (i32.or (i32.const 0x80) (i32.and (i32.shr_u (local.get $cp) (i32.const 6)) (i32.const 0x3F))))
            (i32.store8 (i32.const 3)
              (i32.or (i32.const 0x80) (i32.and (local.get $cp) (i32.const 0x3F))))
            (local.set $len (i32.const 4))))))))
    (i32.store (i32.const 16) (i32.const 0))
    (i32.store (i32.const 20) (local.get $len))
    (drop (call $fd_write (i32.const 1) (i32.const 16) (i32.const 1) (i32.const 24)))
  )

  (func (export "print_char") (param $ch i32)
    ;; Check for UTF-16 surrogate pair handling
    ;; High surrogate: 0xD800..0xDBFF
    (if (i32.and
          (i32.ge_u (local.get $ch) (i32.const 0xD800))
          (i32.le_u (local.get $ch) (i32.const 0xDBFF)))
      (then
        ;; Store high surrogate, wait for low
        (global.set $hi_surrogate (local.get $ch))
        (return)))
    ;; Low surrogate: 0xDC00..0xDFFF
    (if (i32.and
          (i32.ge_u (local.get $ch) (i32.const 0xDC00))
          (i32.le_u (local.get $ch) (i32.const 0xDFFF)))
      (then
        (if (global.get $hi_surrogate)
          (then
            ;; Combine surrogates: cp = 0x10000 + (hi - 0xD800) * 0x400 + (lo - 0xDC00)
            (call $write_utf8
              (i32.add
                (i32.const 0x10000)
                (i32.add
                  (i32.mul
                    (i32.sub (global.get $hi_surrogate) (i32.const 0xD800))
                    (i32.const 0x400))
                  (i32.sub (local.get $ch) (i32.const 0xDC00)))))
            (global.set $hi_surrogate (i32.const 0))
            (return)))))
    ;; Regular codepoint (or unpaired surrogate)
    (global.set $hi_surrogate (i32.const 0))
    (call $write_utf8 (local.get $ch))
  )
)
