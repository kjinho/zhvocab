# zhvocab

Tools to use freely available online Chinese resources to learn
Chinese vocabulary.

The project seeks to rely upon the following resources:

- CEDICT
- SUBTLEX-CH
- Anki

## Usage

To generate the database using the cedict file ```cedict_ts.u8```:

```sh
racket cedict.rkt --init cedict_ts.u8
```

To load the database in racket to make queries:

```racket
(require "cedict.rkt")
(require db)

(define sqldb (sqlite3-connect #:database "cedict.db"))
```

To query the database, use the functions ```search-traditional-word``` and ```search-simplified-word```:

```racket
(search-traditional-word sqldb "行")
;;=> '#("行"
;;      (#("hang2"
;;         "/row/line/commercial firm/line of business/profession/to rank (first, second etc) among one's siblings (by age)/(in data tables) row/(Tw) column/")
;;       #("xing2"
;;         "/to walk/to go/to travel/a visit/temporary/makeshift/current/in circulation/to do/to perform/capable/competent/effective/all right/OK!/will do/behavior/conduct/Taiwan pr. [xing4] for the behavior-conduct sense/")))
(search-traditional-word sqldb "隻")
;;=> '#("只"
;;      (#("zhi1"
;;         "/classifier for birds and certain animals, one of a pair, some utensils, vessels etc/")))
(search-traditional-word sqldb "隻")
;;=> '#("只"
;;      (#("zhi1"
;;         "/classifier for birds and certain animals, one of a pair, some utensils, vessels etc/")))
(search-simplified-word sqldb "只")
;;=> '(#("只" (#("zhi3" "/only/merely/just/but/")))
;;     #("祇" (#("zhi3" "/variant of 只[zhi3]/") #("qi2" "/earth-spirit/peace/")))
;;     #("秖" (#("zhi3" "/grain that has begun to ripen/variant of 衹|只[zhi3]/")))
;;     #("衹"
;;       (#("zhi3" "/variant of 只[zhi3]/")
;;        #("qi2" "/variant of 祇, earth-spirit/peace/")))
;;     #("隻"
;;       (#("zhi1"
;;          "/classifier for birds and certain animals, one of a pair, some utensils, vessels etc/"))))
```
