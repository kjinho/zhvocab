#lang racket/base

;; CEDICT SOURCE

;; SUBTLEX-CH SOURCE
;; https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0010729#s2
;; https://www.ugent.be/pp/experimentele-psychologie/en/research/documents/subtlexch



(require db
         racket/match)


(provide parse-cedict-line
         insert-words-into-db-one-pass
         initialize-db
         search-traditional-word
         search-simplified-word)


(module+ test
  (require rackunit)
  (define testdata "行不顧言 行不顾言 [xing2 bu4 gu4 yan2] /to say one thing and do another (idiom)/")
  (define testdata2 "行 行 [hang2] /row/line/commercial firm/line of business/profession/to rank (first, second etc) among one's siblings (by age)/(in data tables) row/(Tw) column/")
  (define testdata3 "衝擊 冲击 [chong1 ji1] /to attack/to batter/(of waves) to pound against/shock/impact/"))


;; (define sqldb (sqlite3-connect #:database "test.db"))

                     
(define (process-file-by-line filename func)
  (call-with-input-file filename
    (lambda (port)
      (for ([l (in-lines port)])
        (func l)))))


(define (parse-cedict-line str)
  (let ([trad (open-output-string)]
        [simp (open-output-string)]
        [piny (open-output-string)]
        [defs (open-output-string)])
    (define (loop charlist signal)
      (if (null? charlist)
          '()
          (match signal
            ['start (if (char=? (car charlist) #\#)
                        '()
                        (begin
                          (write-char (car charlist) trad)
                          (loop (cdr charlist) 'trad)))]
            ['trad (if (char=? (car charlist) #\space)
                       (loop (cdr charlist) 'simp)
                       (begin
                         (write-char (car charlist) trad)
                         (loop (cdr charlist) 'trad)))]
            ['simp (if (char=? (car charlist) #\space)
                       (loop (cdr charlist) 'piny)
                       (begin
                         (write-char (car charlist) simp)
                         (loop (cdr charlist) 'simp)))]
            ['piny (match (car charlist)
                     [#\[ (loop (cdr charlist) 'piny)]
                     [#\] (loop (cdr charlist) 'defs)]
                     [_ (begin
                          (write-char (car charlist) piny)
                          (loop (cdr charlist) 'piny))])]
            ['defs (if (char=? (car charlist) #\space)
                       (loop (cdr charlist) 'defs)
                       (write-string (list->string charlist) defs))])))
    (begin
      (loop (string->list str) 'start)
      (if (string=? "" (get-output-string trad))
          '()
          (vector (get-output-string trad)
                  (get-output-string simp)
                  (get-output-string piny)
                  (get-output-string defs))))))


(module+ test
  (match (parse-cedict-line testdata)
    [(vector trad simp piny defs)
     (check string=? "行不顧言" trad)
     (check string=? "行不顾言" simp)
     (check string=? "xing2 bu4 gu4 yan2" piny)
     (check string=? "/to say one thing and do another (idiom)/" defs)])
  (match (parse-cedict-line testdata2)
    [(vector trad simp piny defs)
     (check string=? "行" trad)
     (check string=? "行" simp)
     (check string=? "hang2" piny)
     (check string=? "/row/line/commercial firm/line of business/profession/to rank (first, second etc) among one's siblings (by age)/(in data tables) row/(Tw) column/" defs)])
  (match (parse-cedict-line testdata3)
    [(vector trad simp piny defs)
     (check string=? "衝擊" trad)
     (check string=? "冲击" simp)
     (check string=? "chong1 ji1" piny)
     (check string=? "/to attack/to batter/(of waves) to pound against/shock/impact/" defs)]))


(define (insert-words-into-db db line)
  (match (parse-cedict-line line)
    [(vector trad simp _ _)
     (with-handlers ([exn:fail:sql? exn:fail:sql-info])
       (query-exec
        db
        "INSERT INTO words (traditional, simplified) VALUES ($1, $2)"
        trad
        simp))]
    [_ '()]))


(define (insert-pinyin-into-db db line)
  (match (parse-cedict-line line)
    [(vector trad _ piny defs)
     (with-handlers ([exn:fail:sql? exn:fail:sql-info])
       (query-exec
        db
        "INSERT INTO pinyin (pinyin, definition, word_id) SELECT $1, $2, id FROM words WHERE traditional is $3 LIMIT 1"
        piny
        defs
        trad))]
    [_ '()]))


(define (insert-words-into-db-one-pass db line)
  (match (parse-cedict-line line)
    [(vector trad simp piny defs)
     (list
      (with-handlers ([exn:fail:sql? exn:fail:sql-info])
        (query-exec
         db
         "INSERT INTO words (traditional, simplified) VALUES ($1, $2)"
         trad
         simp))
      (with-handlers ([exn:fail:sql? exn:fail:sql-info])
        (query-exec
         db
         "INSERT INTO pinyin (pinyin, definition, word_id) SELECT $1, $2, id FROM words WHERE traditional is $3 LIMIT 1"
         piny
         defs
         trad)))]
    [_ '()]))


(define (initialize-db db-filename cedict-filename)
  (let [(sqldb (sqlite3-connect #:database db-filename #:mode 'create))]
    (begin
      (query-exec
       sqldb
       "CREATE TABLE words ( id integer PRIMARY KEY, traditional text NOT NULL, simplified text NOT NULL, CONSTRAINT word_constraint UNIQUE (traditional) )")
      (query-exec
       sqldb
       "CREATE TABLE pinyin ( id integer PRIMARY KEY, pinyin text NOT NULL, definition text NOT NULL, word_id integer NOT NULL, FOREIGN KEY (word_id) REFERENCES words (id))")
      (process-file-by-line
       cedict-filename
       (lambda (line)
         (insert-words-into-db-one-pass sqldb line)))
      sqldb)))


(define (search-traditional-word db word)
  (match (query-row
          db
          "SELECT id, simplified FROM words WHERE traditional is $1"
          word)
    [(vector id simp)
     (vector
      simp
      (query-rows
       db
       "SELECT pinyin, definition FROM pinyin WHERE word_id is $1" id))]
    [_ '()]))

 
(define (search-simplified-word db word)
  (let* [(words
          (query-rows
           db
           "SELECT id, traditional FROM words WHERE simplified is $1"
           word))]
    (map
     (lambda (x)
       (vector
        (vector-ref x 1)
        (query-rows
         db
         "SELECT pinyin, definition FROM pinyin WHERE word_id is $1"
         (vector-ref x 0))))
     words)))
    

(module+ main
  (require racket/cmdline)
  (define dbfilename (make-parameter "cedict.db"))
  (define initdbfile (make-parameter '()))
  (define main-process
    (command-line
     #:program "cedictdb"
     #:once-each
     ["--init"
      filename
      "initialize the database with the given cedict file"
      (initdbfile filename)]
     ["--db-file"
      filename
      "choose the database file to use"
      (dbfilename filename)]
     #:args allargs
     allargs))
  (if (string? (initdbfile))
      (begin
        (println "Initializing database")
        (time
         (initialize-db (dbfilename) (initdbfile)))
        (println "Done!"))
      (println "Nothing to do!")))      
               

