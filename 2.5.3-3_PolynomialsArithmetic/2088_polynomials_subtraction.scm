; ***************operation-and-type table**********************
(define op-type-table (make-hash-table))
(define (put op-name data-type procdure)
  (hash-table/put! op-type-table (list op-name data-type) procdure))
(define (get op-name data-type)
  (hash-table/get op-type-table (list op-name data-type) #f))
; ***************operation-and-type table(end)*******************

; ******operation-and-type table for coercion*****************
(define op-type-table-coercion (make-hash-table))
(define (put-coercion data-type-1 data-type-2 procdure)
  (hash-table/put! op-type-table-coercion (list data-type-1 data-type-2) procdure))
(define (get-coercion data-type-1 data-type-2)
  (hash-table/get op-type-table-coercion (list data-type-1 data-type-2) #f))
; *****operation-and-type table for coercion(end)***************

; ******table for the height of one type in a tower of types*****************
(define type-height-table (make-hash-table))
(define (put-height data-type height)
  (hash-table/put! type-height-table data-type height))
(define (get-height data-type)
  (hash-table/get type-height-table data-type #f))
; ******table for the height of one type in a tower of types(end)*****************

; **********************type tag operations********************
(define (attach-tag tag-name contents)
  (if (eq? tag-name 'scheme-number)
      contents
      (cons tag-name contents)))
(define (type-tag datum)
  (cond ((pair? datum) (car datum))
        ((number? datum) 'real) ; treat scheme-number as real
        (else (error "Bad tagged datum -- TYPE-TAG" datum))))
(define (contents datum)
  (cond ((pair? datum) (cdr datum))
        ((number? datum) datum)
        (else (error "Bad tagged datum -- CONTENTS" datum))))
; **********************type tag operations(end)********************

; *****************apply generic*****************
(define (apply-generic op . args)
  (let ((type-tags (map type-tag args)))
    (let ((proc (get op type-tags)))
      (if proc
          ;add drop here will cause problem
          ;because except add, many other operation use apply-generic
          ;such as numer
          ;add here need to spacify operations that really needs to use drop
          ;such as add, sub
          (if (or (eq? op 'add)
                  (eq? op 'sub)
                  (eq? op 'mul)
                  (eq? op 'div))
              (drop (apply proc (map contents args)))
              (apply proc (map contents args)))
          (if (= (length args) 2)
              (let ((type1 (car type-tags))
                    (type2 (cadr type-tags))
                    (a1 (car args))
                    (a2 (cadr args)))
                (let ((height1 (get-height type1))
                      (height2 (get-height type2)))
                  (if (and height1 height2)
                      (if (> height1 height2)
                          (apply-generic op a1 (raise-n (- height1 height2) a2))
                          (apply-generic op (raise-n (- height2 height1) a1) a2))
                      (error "No method for these types"
                                    (list op type-tags)))))
              (error "No method for these types"
                     (list op type-tags)))))))
; *****************apply generic(end)*****************


; **********************rectangular package**********************
(define (install-rectangular-package)
  ; internal procedures
  ; 因为scheme中自带real-part等方法,所以自己定义的方法在后面加上字符以区别
  (define (real-part-x z) (car z))
  (define (imag-part-x z) (cdr z))
  (define (make-from-real-imag x y) (cons x y))
  (define (magnitude-x z)
    (sqrt-x (add (square-x (real-part-x z))
             (square-x (imag-part-x z)))))
  (define (angle-x z)
    (atan-x (imag-part-x z) (real-part-x z)))
  (define (make-from-mag-ang r a) 
    (cons (mul r (cos-x a)) (mul r (sin-x a))))
  ;; interface to the rest of the system
  (define (tag x) (attach-tag 'rectangular x))
  (put 'real-part-x '(rectangular) real-part-x)
  (put 'imag-part-x '(rectangular) imag-part-x)
  (put 'magnitude-x '(rectangular) magnitude-x)
  (put 'angle-x '(rectangular) angle-x)
  (put 'make-from-real-imag 'rectangular 
       (lambda (x y) (tag (make-from-real-imag x y))))
  (put 'make-from-mag-ang 'rectangular 
       (lambda (r a) (tag (make-from-mag-ang r a))))
  'rectangular-done)
; *******************rectangular package(end)**********************

; **********************polar package***************************
(define (install-polar-package)
  ;; internal procedures
  (define (magnitude-x z) (car z))
  (define (angle-x z) (cdr z))
  (define (make-from-mag-ang r a) (cons r a))
  (define (real-part-x z)
    (mul (magnitude-x z) (cos-x (angle-x z))))
  (define (imag-part-x z)
    (mul (magnitude-x z) (sin-x (angle-x z))))
  (define (make-from-real-imag x y) 
    (cons (sqrt-x (add (square-x x) (square-x y)))
          (atan-x y x)))
  ;; interface to the rest of the system
  (define (tag x) (attach-tag 'polar x))
  (put 'real-part-x '(polar) real-part-x)
  (put 'imag-part-x '(polar) imag-part-x)
  (put 'magnitude-x '(polar) magnitude-x)
  (put 'angle-x '(polar) angle-x)
  (put 'make-from-real-imag 'polar
       (lambda (x y) (tag (make-from-real-imag x y))))
  (put 'make-from-mag-ang 'polar 
       (lambda (r a) (tag (make-from-mag-ang r a))))
  'polar-done)
; *******************polar package(end)***************************

; ******************complex package********************
(define (install-complex-package)
  ;; imported procedures from rectangular and polar packages
  (define (make-from-real-imag x y)
    ((get 'make-from-real-imag 'rectangular) x y))
  (define (make-from-mag-ang r a)
    ((get 'make-from-mag-ang 'polar) r a))
  
  ; NOTIC!, add-complex need the methods below
  (define (real-part-x c) (apply-generic 'real-part-x c))
  (define (imag-part-x c) (apply-generic 'imag-part-x c))
  (define (magnitude-x c) (apply-generic 'magnitude-x c))
  (define (angle-x c) (apply-generic 'angle-x c))

  ;; internal procedures
  (define (add-complex z1 z2)
    (make-from-real-imag (add (real-part-x z1) (real-part-x z2))
                         (add (imag-part-x z1) (imag-part-x z2))))
  (define (sub-complex z1 z2)
    (make-from-real-imag (sub (real-part-x z1) (real-part-x z2))
                         (sub (imag-part-x z1) (imag-part-x z2))))
  (define (mul-complex z1 z2)
    (make-from-mag-ang (mul (magnitude-x z1) (magnitude-x z2))
                       (add (angle-x z1) (angle-x z2))))
  (define (div-complex z1 z2)
    (make-from-mag-ang (div (magnitude-x z1) (magnitude-x z2))
                       (sub (angle-x z1) (angle-x z2))))
  (define (neg-complex z)
    (make-from-real-imag (sub 0 (real-part-x z))
                         (sub 0 (imag-part-x z))))
  (define (equ?-complex z1 z2)
    (and (equ? (real-part-x z1) (real-part-x z2))
         (equ? (imag-part-x z1) (imag-part-x z2))))
  (define (=zero?-complex z)
    (and (equ? (real-part-x z) (make-integer 0))
         (equ? (imag-part-x z) (make-integer 0))))

  ;; interface to rest of the system
  (define (tag z) (attach-tag 'complex z))
  (put 'real-part-x '(complex) real-part-x)
  (put 'imag-part-x '(complex) imag-part-x)
  (put 'magnitude-x '(complex) magnitude-x)
  (put 'angle-x '(complex) angle-x)
  (put 'add '(complex complex)
       (lambda (z1 z2) (tag (add-complex z1 z2))))
  (put 'sub '(complex complex)
       (lambda (z1 z2) (tag (sub-complex z1 z2))))
  (put 'mul '(complex complex)
       (lambda (z1 z2) (tag (mul-complex z1 z2))))
  (put 'div '(complex complex)
       (lambda (z1 z2) (tag (div-complex z1 z2))))
  (put 'neg '(complex)
       (lambda (z) (tag (neg-complex z))))
  (put 'equ? '(complex complex) equ?-complex)
  (put '=zero? '(complex) =zero?-complex)

  ; could not use scheme-number as input, need to specfy type when use make, 
  ; such as 1 must be (integer 1)
  (put 'make-from-real-imag 'complex
       (lambda (x y) (tag (make-from-real-imag x y))))   
  (put 'make-from-mag-ang 'complex
       (lambda (r a) (tag (make-from-mag-ang r a))))
  'complex-done)
; ******************complex package(end)********************

; ******************real package********************
(define (install-real-package)
  (define (tag x)
    (attach-tag 'real x))    
  (put 'add '(real real)
       (lambda (x y) (tag (+ x y))))
  (put 'sub '(real real)
       (lambda (x y) (tag (- x y))))
  (put 'mul '(real real)
       (lambda (x y) (tag (* x y))))
  (put 'div '(real real)
       (lambda (x y) (tag (/ x y))))
  (put 'neg '(real)
       (lambda (x) (tag (- x))))
  (put 'square-x '(real)
       (lambda (x) (tag (square x))))
  (put 'sqrt-x '(real)
       (lambda (x) (tag (sqrt x))))
  (put 'atan-x '(real real)
       (lambda (x y) (tag (atan x y))))
  (put 'cos-x '(real)
       (lambda (x) (tag (cos x))))
  (put 'sin-x '(real)
       (lambda (x) (tag (sin x))))
  (put 'equ? '(real real) =)
  (put '=zero? '(real)
       (lambda (x) (= x 0)))
  (put 'make 'real
       (lambda (x) (tag x)))
  'real-done)
; ******************real package(end)*****************

; ****************retional number package***************
(define (install-rational-package)
  ;; internal procedures
  (define (numer x) (car x))
  (define (denom x) (cdr x))
  (define (make-rat n d)
    (let ((g (gcd n d)))
      (cons (/ n g) (/ d g))))
  (define (add-rat x y)
    (make-rat (+ (* (numer x) (denom y))
                 (* (numer y) (denom x)))
              (* (denom x) (denom y))))
  (define (sub-rat x y)
    (make-rat (- (* (numer x) (denom y))
                 (* (numer y) (denom x)))
              (* (denom x) (denom y))))
  (define (mul-rat x y)
    (make-rat (* (numer x) (numer y))
              (* (denom x) (denom y))))
  (define (div-rat x y)
    (make-rat (* (numer x) (denom y))
              (* (denom x) (numer y))))
  (define (neg-rat x)
    (make-rat (- (numer x)) (denom x)))
  (define (square-rat x)
    (make-rat (square (numer x)) (square (denom x))))
  ; There may be problem here, numer/denom may not be integer
  ; (sqrt 2) is 1.414...
  ; can be coverted to op on real, but use raise here is not good
  ; so change apply-generic that make it to raise a type when this type has no
  ; operation on the type, and not define sqrt operation for rational
  ; anoter way is converted to real, here use this way(this works but use make-real
  ; which is not in this package
  (define (sqrt-rat x)
    (make-real (sqrt (/ (numer x) (denom x)))))
  (define (atan-rat x y)
    (make-real (atan (/ (numer x) (denom x)) (/ (numer y) (denom y)))))
  (define (cos-rat x)
    (make-real (cos (/ (numer x) (denom x)))))
  (define (sin-rat x)
    (make-real (sin (/ (numer x) (denom x)))))
  (define (equ?-rat x y)
    (and (= (numer x) (numer y))
         (= (denom x) (denom y))))
  (define (=zero?-rat x)
    (= (numer x) 0))
  ;; interface to rest of the system
  (define (tag x) (attach-tag 'rational x))
  (put 'add '(rational rational)
       (lambda (x y) (tag (add-rat x y))))
  (put 'sub '(rational rational)
       (lambda (x y) (tag (sub-rat x y))))
  (put 'mul '(rational rational)
       (lambda (x y) (tag (mul-rat x y))))
  (put 'div '(rational rational)
       (lambda (x y) (tag (div-rat x y))))
  (put 'neg '(rational)
       (lambda (x) (tag (neg-rat x))))
  (put 'square-x '(rational)
       (lambda (x) (tag (square-rat x))))
  (put 'sqrt-x '(rational)
       (lambda (x) (sqrt-rat x)))
  (put 'atan-x '(rational rational)
       (lambda (x y) (atan-rat x y)))
  (put 'cos-x '(rational)
       (lambda (x) (cos-rat x)))
  (put 'sin-x '(rational)
       (lambda (x) (sin-rat x)))
  (put 'equ? '(rational rational) equ?-rat)
  (put '=zero? '(rational) =zero?-rat)
  (put 'numer '(rational) numer)
  (put 'denom '(rational) denom)

  (put 'make 'rational
       (lambda (n d) (tag (make-rat n d))))
  'rational-done)
; ****************retional number package(end)***************

; ******************integer package********************
(define (install-integer-package)
  (define (tag x)
    (attach-tag 'integer x))    
  (put 'add '(integer integer)
       (lambda (x y) (tag (+ x y))))
  (put 'sub '(integer integer)
       (lambda (x y) (tag (- x y))))
  (put 'mul '(integer integer)
       (lambda (x y) (tag (* x y))))
  (put 'div '(integer integer) ; after dividing, you get a real
       (lambda (x y) (make-real (/ x y))))
  (put 'neg '(integer)
       (lambda (x) (tag (- x))))
  (put 'square-x '(integer)
       (lambda (x) (tag (square x))))
  (put 'sqrt-x '(integer)
       (lambda (x) (make-real (sqrt x))))
  (put 'atan-x '(integer integer)
       (lambda (x y) (make-real (atan x y))))
  (put 'cos-x '(integer)
       (lambda (x) (make-real (cos x))))
  (put 'sin-x '(integer)
       (lambda (x) (make-real (sin x))))
  (put 'equ? '(integer integer) =)
  (put '=zero? '(integer)
       (lambda (x) (= x 0)))
  (put 'make 'integer
       (lambda (x) (tag x)))
  'integer-done)
; ******************integer package(end)*****************

; ******************scheme number package********************
(define (install-scheme-number-package)
  (define (tag x)
    (attach-tag 'scheme-number x))    
  (put 'add '(scheme-number scheme-number)
       (lambda (x y) (tag (+ x y))))
  (put 'sub '(scheme-number scheme-number)
       (lambda (x y) (tag (- x y))))
  (put 'mul '(scheme-number scheme-number)
       (lambda (x y) (tag (* x y))))
  (put 'div '(scheme-number scheme-number)
       (lambda (x y) (make-real (/ x y))))
  (put 'neg '(scheme-number)
       (lambda (x) (tag (- x))))
  (put 'square-x '(scheme-number)
       (lambda (x) (tag (square x))))
  (put 'sqrt-x '(scheme-number)
       (lambda (x) (make-real (sqrt x))))
  (put 'atan-x '(scheme-number scheme-number)
       (lambda (x y) (make-real (atan x y))))
  (put 'cos-x '(scheme-number)
       (lambda (x) (make-real (cos x))))
  (put 'sin-x '(scheme-number)
       (lambda (x) (make-real (sin x))))
  (put 'equ? '(scheme-number scheme-number) =)
  (put '=zero? '(scheme-number)
       (lambda (x) (= x 0)))
  (put 'make 'scheme-number
       (lambda (x) (tag x)))
  'scheme-number-done)
; ******************scheme number package(end)*****************

; ****************polynomial package**************
(define (install-polynomial-package)
  ;; internal procedures
  ;; representation of poly
  (define (variable? x) (symbol? x))
  (define (same-variable? v1 v2)
    (and (variable? v1) (variable? v2) (eq? v1 v2)))

  (define (make-poly variable term-list)
    (cons variable term-list))
  (define (variable p) (car p))
  (define (term-list p) (cdr p))

  ; when p is "0", we can see from adjoin-term that p's term-list will be empty,
  ; because when the integer/rational/real coefficident equals to zero, 
  ; then the term will not be added, thus make p empty 
  (define (=zero? p) 
    (eq? (term-list p) (the-empty-termlist)))
  (define (add-poly p1 p2)
    (if (same-variable? (variable p1) (variable p2))
        (make-poly (variable p1)
                   (add-terms (term-list p1)
                              (term-list p2)))
        (error "Polys not in same var -- ADD-POLY"
               (list p1 p2))))
  (define (sub-poly p1 p2)
    (if (same-variable? (variable p1) (variable p2))
        (add-poly p1 (neg-poly p2))
        (error "Polys not in same var -- SUB-POLY"
               (list p1 p2))))
  (define (mul-poly p1 p2)
    (if (same-variable? (variable p1) (variable p2))
        (make-poly (variable p1)
                   (mul-terms (term-list p1)
                              (term-list p2)))
        (error "Polys not in same var -- MUL-POLY"
               (list p1 p2))))
  (define (neg-poly p) (make-poly (variable p) (neg-terms (term-list p))))

  ;; representation of terms and term lists
  (define (the-empty-termlist) '())
  (define (first-term term-list) (car term-list))
  (define (rest-terms term-list) (cdr term-list))
  (define (empty-termlist? term-list) (null? term-list))
  (define (make-term order coeff) (list order coeff))
  (define (order term) (car term))
  (define (coeff term) (cadr term))
  (define (adjoin-term term term-list)
    (if (=zero? (coeff term))
        term-list
        (cons term term-list)))
  (define (add-terms L1 L2)
    (cond ((empty-termlist? L1) L2)
          ((empty-termlist? L2) L1)
          (else
           (let ((t1 (first-term L1)) (t2 (first-term L2)))
             (cond ((> (order t1) (order t2))
                    (adjoin-term
                     t1 (add-terms (rest-terms L1) L2)))
                   ((< (order t1) (order t2))
                    (adjoin-term
                     t2 (add-terms L1 (rest-terms L2))))
                   (else
                    (adjoin-term
                     (make-term (order t1)
                                (add (coeff t1) (coeff t2)))
                     (add-terms (rest-terms L1)
                                (rest-terms L2)))))))))
  (define (mul-terms L1 L2)
    (if (empty-termlist? L1)
        (the-empty-termlist)
        (add-terms (mul-term-by-all-terms (first-term L1) L2)
                   (mul-terms (rest-terms L1) L2))))
  (define (mul-term-by-all-terms t1 L)
    (if (empty-termlist? L)
        (the-empty-termlist)
        (let ((t2 (first-term L)))
          (adjoin-term
           (make-term (+ (order t1) (order t2))
                      (mul (coeff t1) (coeff t2))) ; depends on mul
           (mul-term-by-all-terms t1 (rest-terms L))))))
  
  (define (neg-terms L)
    (if (empty-termlist? L)
        (the-empty-termlist)
        (let ((t (first-term L)))
          (adjoin-term
            (make-term (order t) (neg (coeff t)))
            (neg-terms (rest-terms L))))))

  ;; interface to rest of the system
  (define (tag p) (attach-tag 'polynomial p))
  (put 'add '(polynomial polynomial) 
       (lambda (p1 p2) (tag (add-poly p1 p2))))
  (put 'sub '(polynomial polynomial)
       (lambda (p1 p2) (tag (sub-poly p1 p2))))
  (put 'mul '(polynomial polynomial) 
       (lambda (p1 p2) (tag (mul-poly p1 p2))))
  (put 'neg '(polynomial)
       (lambda (p) (tag (neg-poly p))))
  (put 'make 'polynomial
       (lambda (var terms) (tag (make-poly var terms))))
  'done)
; ****************polynomial package(end)**************

; *************height of type in a tower of types****************
;  complex
;    ^
;    |
;   real
;    ^
;    |
; rational
;    ^
;    |
;  integer
(put-height 'integer 1)
(put-height 'rational 2)
(put-height 'real 3)
(put-height 'complex 4)
; *************height of type in a tower of types(end)****************

; *************raise******************
(put 'raise 'integer
     (lambda (i) (make-rational (contents i) 1)))
(put 'raise 'rational
     (lambda (ra) (make-real (exact->inexact (/ (numer ra) (denom ra))))))
(put 'raise 'real
     (lambda (re) (make-complex-from-real-imag (make-real (contents re)) (make-real 0)))); notic: must add make-real
(define (raise x)
  ((get 'raise (type-tag x)) x))
; *************raise(end)******************

; *************raise height of difference n******************
(define (raise-n n x)
  (if (> n 0)
      (raise-n (- n 1) (raise x))
      x))
; *************raise height of difference n(end)******************

; *************project*******************
; push an object down in a tower
(put 'project 'complex
  (lambda (c) (make-real 
                (let* ((real-part-c (real-part-x c))
                       (type-of-real-part (type-tag real-part-c)))
                  (if (eq? type-of-real-part 'rational)
                      (exact->inexact (/ (numer real-part-c) (denom real-part-c)))
                      (contents real-part-c))))))
(put 'project 'real
  (lambda (re) (make-rational (round (contents re)) 1)))
  ;Note: there is a better way to project real to rational
  ;      {multiply a real number re by a integer i that 
  ;      (/ (round (* re i)) i) is near re, so real number re 
  ;      is projected to rational (rational (round (* re i)) i)}, 
  ;      but this is not the key in this exercise, so we just use
  ;      the naive way to do the projection
(put 'project 'rational
  (lambda (ra) (make-integer (round (exact->inexact (/ (numer ra) (denom ra)))))))
(define (project x)
  (let ((pr (get 'project (type-tag x))))
    (if pr
        (pr x)
        #f))) ; when there is no method to project a type, return #f
; *************project(end)*******************

; *************drop****************
; drop a data as far as possible
(define (drop x)
  (let ((projected-x (project x)))
    (if projected-x
        (if (equ? x (raise projected-x))
            (drop projected-x)
            x)
        x)))
; *************drop(end)****************

; *************set generic arithmetic interface**************
; install packages
(install-rectangular-package)
(install-polar-package)
(install-complex-package)
(install-real-package)
(install-rational-package)
(install-integer-package)
(install-scheme-number-package)
(install-polynomial-package)

; define number constructors
; complex can only be made from integer/rational/real, cannot be made from scheme-number
; integer/rational/real can only be made from scheme-number
;         complex
;            ^
;            |
;    +-------+------+
;    |       |      |
; integer rational real
;    ^       ^      ^
;    |       |      |
;      scheme-number
(define (make-complex-from-real-imag x y)
  ((get 'make-from-real-imag 'complex) x y))
(define (make-complex-from-mag-ang r a)
  ((get 'make-from-mag-ang 'complex) r a))
(define (make-real n)
  ((get 'make 'real) n))
(define (make-rational n d)
  ((get 'make 'rational) n d))
(define (make-integer n)
  ((get 'make 'integer) n))
(define (make-scheme-number n)
  ((get 'make 'scheme-number) n))
(define (make-polynomial var terms)
  ((get 'make 'polynomial) var terms))

; define number selectors
(define (real-part-x c) (apply-generic 'real-part-x c))
(define (imag-part-x c) (apply-generic 'imag-part-x c))
(define (magnitude-x c) (apply-generic 'magnitude-x c))
(define (angle-x c) (apply-generic 'angle-x c))
(define (numer r) (apply-generic 'numer r))
(define (denom r) (apply-generic 'denom r))

; define arithmetic operations
(define (add x y) (apply-generic 'add x y))
(define (sub x y) (apply-generic 'sub x y))
(define (mul x y) (apply-generic 'mul x y))
(define (div x y) (apply-generic 'div x y))
(define (neg x) (apply-generic 'neg x))
(define (square-x x) (apply-generic 'square-x x))
(define (sqrt-x x) (apply-generic 'sqrt-x x))
(define (atan-x x y) (apply-generic 'atan-x x y))
(define (cos-x x) (apply-generic 'cos-x x))
(define (sin-x x) (apply-generic 'sin-x x))
(define (equ? x y) (apply-generic 'equ? x y))
(define (=zero? x) (apply-generic '=zero? x))
; *************set generic arithmetic interface(end)**************


; *************debug********************
;(trace-both magnitude-x)
;(trace-both apply-generic)
;(trace-both add)
;(trace-both get-coercion)
;(trace-both raise-n)
;(trace-both raise)
;(trace-both type-tag)
; *************debug(end)*******************

; ************* test ********************
(define c1 (make-complex-from-real-imag 1 2))
(define c2 (make-complex-from-real-imag 2 3))
(define c3 (make-complex-from-real-imag 2 0)) ; can be dropped to integer
(define c4 (make-complex-from-real-imag 2.1 0)) ; can be dropped to real
(define re1 (make-real 4.5))
(define re2 (make-real 5.6))
(define r1 (make-rational 1 2))
(define r2 (make-rational 8 9))
(define r3 (make-rational 3 2))
(define r4 (make-rational 6 3))
(define i1 (make-integer 4))
(define i2 (make-integer 5))
(define c5 (make-complex-from-real-imag i1 i2))
(define c6 (make-complex-from-real-imag r1 r2))
(define c7 (make-complex-from-real-imag r3 r4))
(define t0 (list 1 re2))
(define t1 (list 2 r1))
(define t2 (list 1 c1))
(define t3 (list 2 re1))
(define tl1 (list t0 t1))
(define tl2 (list t2 t3))
(define p1 (make-polynomial 'x tl1))
(define p2 (make-polynomial 'x tl2))
(define t4 (list 2 p1))
(define tl4 (list t1))
(define tl3 (list t4))
(define p3 (make-polynomial 'x tl3))
(define p4 (make-polynomial 'x tl4))

;(define r->s (rational->scheme-number r1))
;(define s->c (scheme-number->complex s1))
;(define r+s (add r1 s1))
;(define s+c (add s1 c1))
; ************* test(end) ****************
