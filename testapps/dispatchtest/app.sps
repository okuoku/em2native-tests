(import (yuni scheme)
        (yuni ffi nccc)
        (yuni hashtables)
        (yuni compat ffi primitives)
        (yuni compat bitwise primitives))

(define lib/nccc-core (begin
                        (nccc-set-modpath0! %%selfboot-current-modpath)
                        (nccc-loadlib "nccc_corelib" "nccc_corelib")))

(define lib/nccc-test (begin
                        (nccc-set-modpath0! %%selfboot-current-modpath)
                        (nccc-loadlib "tests_nccc" "tests_nccc")))

(define callctx (make-nccc-call-ctx))

(define (func-realize lib sym)
  (define str (symbol->string sym))
  (let ((func (cdr (hashtable-ref lib str #f))))
   (lambda x (apply func callctx x))))

(define (ptr-realize lib sym)
  (define str (symbol->string sym))
  (let ((func (car (hashtable-ref lib str #f))))
   func))
 
(define-syntax def-funcs
  (syntax-rules ()
    ((_ lib nam ...)
     (begin
       (define nam (func-realize lib 'nam)) ...))))

(define-syntax def-ptrs
  (syntax-rules ()
    ((_ lib (def nam) ...)
     (begin
       (define def (ptr-realize lib 'nam)) ...))))

(def-ptrs lib/nccc-core
          (&nccc_dispatch_0 nccc_dispatch_0))

(def-ptrs lib/nccc-test
          (&test_retm10_s32 test_retm10_s32))


(define nccc-dispatch (nccc-loaddispatch))



;; 2 step call test
;;
;; nccc_dispatch0[[CALL &test_retm10_s32 [] [buf2]] [RETURN]]
;;   0: buf1
;;   1: buf2
;;   
;;   CALL
;;   &test_retm10_s32
;;   <dummy>
;;   <buf2>
;;   RETURN
;; 
;; buf1(buf2) = [
;; ]
;;
;; buf1(buf2) = [
;;   0: 2 0 buf1 12    [MOVPTR 0 buf2 HOLE1]
;;   4: 3 X buf1[9] 0  [CALL &nccc_dispatch0 CHAIN NULL]
;;   8: 0              [RETURN]
;;   9: 3 Y 0 _        CHAIN: [CALL &test_ret10_s32 NULL HOLE1(buf2)]
;;  13: 0              [RETURN]
;; ]
;;
;; buf2(bytevector) = [s32]

(define buf1 (buf-alloc (* 8 14)))
(define buf2 (make-bytevector 8))

;; Fill buf1 content
(ptr-write/uptr! buf1 0 2)
(ptr-write/uptr! buf1 (* 8 1) 0)
(ptr-write/uptr! buf1 (* 8 2) buf1)
(ptr-write/uptr! buf1 (* 8 3) 13) ;; => HOLE1
(ptr-write/uptr! buf1 (* 8 4) 3)
(ptr-write/uptr! buf1 (* 8 5) &nccc_dispatch_0)
(ptr-write/uptr! buf1 (* 8 6) (+ buf1 (* 8 9)))
(ptr-write/uptr! buf1 (* 8 7) 0)
(ptr-write/uptr! buf1 (* 8 8) 0)
(ptr-write/uptr! buf1 (* 8 9) (+ buf1 (* 8 10))) ;; => CHAIN
(ptr-write/uptr! buf1 (* 8 10) 3)
(ptr-write/uptr! buf1 (* 8 11) &test_retm10_s32)
(ptr-write/uptr! buf1 (* 8 12) 0)
(ptr-write/uptr! buf1 (* 8 13) 0) ;; <= HOLE1
(ptr-write/uptr! buf1 (* 8 14) 0)

(nccc-dispatch buf1 buf1 buf2)


(write (list 'OUT: (bv-read/s32 buf2 0))) (newline)
