(use srfi-1)
(use util.match)

(define (x86 program)
  (x86-assemble program "t.s")
  (printf "running gcc\n")
  (sys-system "gcc -m32 startup.c call_scheme.s t.s -o a.out"))

(define (x86-assemble code file)
  (with-output-to-file file
    (lambda ()
      (x86-spit (registerize code)))))

(define registerize
  (let ([regs '((fp . ebp) (cp . esi) (ap . edi) (ac . eax) (t1 . ebx) (t2 . ecx) (t3 . edx))])
    (lambda (thing)
      (cond
        [(pair? thing)
         (let ([x (assq (car thing) regs)])
           (if x
               `(reg-off (reg ,(cdr x)) ,(cadr thing))
               (map registerize thing)))]
        [(and (symbol? thing) (assq thing regs)) =>
         (lambda (x)
           `(reg ,(cdr x)))]
        [else thing]))))

(define (x86-spit ls)
  (define (print-elem obj)
    (cond
      [(pair? obj)
       (match obj
         [('reg name)
          (printf "%~s" name)]
         [('reg-off reg off)
          (let ([name (cadr reg)])
            (printf "~s(%~s)" off name))]
         [('delim)
          (printf ", ")]
         [('near x)
          (printf "*")
          (print-elem x)]
         [('imm x)
          (printf "$")
          (print-elem x)])]
      [(string? obj)
       (printf "\t# ~a " obj)]
      [(number? obj)
       (printf "$~a" obj)]
      [else (printf "~a" obj)]))
  (define (insert-delimiter rands)
    (reverse
      (fold (lambda (exp ls)
              (if (string? exp)
                  (cons exp ls)
                  (cons exp (cons '(delim) ls))))
            (cons (car rands) '())
            (cdr rands))))
  (printf "\t.code32\n")
  (printf "\t.align 4\n")
  (printf "\t.global _scheme_entry\n")
  (let loop ([ls (cdr ls)])
    (unless (null? ls)
      (let ([inst (car ls)])
        (case (car inst)
          [(comment)
           (printf "\t\t# ~a " (cadr inst))]
          [(label)
           (printf "~a:" (cadr inst))]
          [else
           (let ([rands (insert-delimiter (cdr inst))])
             (printf "\t~s\t" (car inst))
             (for-each print-elem rands))]))
      (newline)
      (loop (cdr ls)))))

(define (printf . x)
  (apply format #t x))