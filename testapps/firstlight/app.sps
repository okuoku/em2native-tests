(import (yuni scheme)
        (yuni ffi nccc)
        (yuni hashtables)
        (yuni compat ffi primitives)
        (yuni compat bitwise primitives))

(define lib/yfrm (begin
                   (nccc-set-modpath0! %%selfboot-current-modpath)
                   (nccc-loadlib "yfrm" "yfrm")))

(define lib/cwgl (begin
                   (nccc-set-modpath0! %%selfboot-current-modpath)
                   (nccc-loadlib "yfrm" "cwgl")))

(define callctx (make-nccc-call-ctx))

(define (func-realize lib sym)
  (define str (symbol->string sym))
  (let ((func (cdr (hashtable-ref lib str #f))))
   (lambda x (apply func callctx x))))

(define-syntax def-funcs
  (syntax-rules ()
    ((_ lib nam ...)
     (begin
       (define nam (func-realize lib 'nam)) ...))))

(def-funcs lib/yfrm
           yfrm_init
           yfrm_terminate
           yfrm_cwgl_ctx_create
           yfrm_query0
           yfrm_wait0
           yfrm_frame_begin0
           yfrm_frame_end0)

(def-funcs lib/cwgl
           cwgl_viewport
           cwgl_clear
           cwgl_clearColor)

(define cur 0.0)
(define evq (buf-alloc (* 4 256)))

(define COLOR_BUFFER_BIT #x4000)
(define (fill ctx cur)
  (yfrm_frame_begin0 ctx)
  (cwgl_clearColor ctx cur cur cur cur)
  (cwgl_clear ctx COLOR_BUFFER_BIT)
  (yfrm_frame_end0 ctx))

(define (step ctx)
  (yfrm_wait0 0)
  (let ((r (yfrm_query0 0 evq (* 4 256))))
   (write (list 'EVENT: r)) (newline)
   (set! cur (+ 0.05 cur))
   (when (< 1.0 cur)
     (set! cur (- cur 1.0)))
   (display cur) (newline)
   (fill ctx cur)
   (step ctx)))

(let* ((initr (yfrm_init))
       (ctx-cwgl (yfrm_cwgl_ctx_create 1280 720 0 1)))
  (cwgl_viewport ctx-cwgl 0 0 1280 720)
  (step ctx-cwgl))

