# library

import "./easy_html.nim"
import "easy_http.nim"

# import std/strutils

# htmlText functions

proc p(str: string; style="") =
    html "p":
        if len(style) > 0:
            css "me {" & style & "}"
        htmlText str

proc h1(str: string; style="") =
    html "h1":
        if len(style) > 0:
            css "me {" & style & ")"
        htmlText str

proc h2(str: string; style="") =
    html "h2":
        if len(style) > 0:
            css "me {" & style & ")"
        htmlText str

proc h3(str: string; style="") =
    html "h3":
        if len(style) > 0:
            css "me {" & style & ")"
        htmlText str



# boilerplate

proc basicPage(title: string) {.htmlTmpl: "html".} =
    html "head":
        html "title":
            htmlText title
        html "script":
            attr("src", "./htmx.min.js")
        html "script":
            attr("src", "./cssMe.js")
        html "body":
            pasteBody()

# style


proc header() {.htmltmpl: "div".} =
    css """
    me {
        display: fixed;
        background-color: black;
        padding: 3px;
        text-align: center;
    }
        """
    pasteBody()

proc section() {.htmlTmpl: "div".} =
    css """
    me {
        text-align: center;
        background-color: rgb(75, 75, 75);
        padding: 30px 0 0;
    } 
    me h3 {
        background-color: rgb(39, 39, 39);
    }
        """
    pasteBody()

proc imgCnt() {.htmlTmpl: "div".} =
    css """
    me {
        display: flex;
        width: 95%;
        padding: 30px;
    } 
    me img {
        width: 50%;
    }
    me p {
        display: flex;
        align-items: center;
        width: 50%;
        justify-content: center;
        padding: 30px;
    }
        """
    pasteBody()

# style: body

proc page() {.htmlTmpl: basicPage("Styles of Elvis").} =
    css """
    me {
        background-color: gray;
        color: white;
        font-family: sans-serif;
    }
        """


# html body
    html header():
        h1("Elvis Presley")

    h2("Here is how the style of elvis changed over his 23 year career", style="text-align: center;")

    html section():
        h3("1954-1957")
        html imgCnt():
            html "img src=media/pics/elvis-56.png":
                discard
            p("This picture is from 1956. As you can see, in the mid 1950s he dressed in a loose suit. He was cool, but he hadn't tapped into his style yet.")

    html section():
        h3("1958-1959")
        html imgCnt():
            html "img src=media/pics/elvis-59.jpg":
                discard
            p("This picture is from 1959. Elvis got drafted and spent 2 years in the army as a tank driver. He definitely pulled off the army look.")

    html section():
        h3("1960-1967")
        html imgCnt():
            html "img src=media/pics/elvis-64.webp":
                discard
            p("This picture is from 1964. Elvis was back from the army, making lots of movies and he was starting to get into his style. One of his most iconic looks is the popped collar shirt. He also started to wear more flashy clothes.")

    html section():
        h3("1968")
        html imgCnt():
            html "img src=media/pics/elvis-68.jpg":
                discard
            p("This is from the famous '68 Comeback Special. He wore a black leather suit and he was looking awesome! This was a prelude to his awesome style in the 70s.")

    html section():
        h3("1969")
        html imgCnt():
            html "img src=media/pics/elvis-69.jpg":
                discard
            p("In 1969 his style was similar to the rest of the 60s, but he started to wear more jewelry and grew awesome sideburns.")

    html section():
        h3("1970")
        html imgCnt():
            html "img src=media/pics/elvis-70.jpg":
                discard
            p("1970 was an huge moment for Elvis! He began wearing these fantastic jumpsuits! This is the first jumpsuit that he wore in the 70s. He was looking awesome!")

    html section():
        h3("1971-1977")
        html imgCnt():
            html "img src=media/pics/elvis-70s.jpg":
                discard
            p("I'm not sure exactly when this picture was taken, but it's from the 70s. This jumpsuit is one of my favorites. His jumpsuits just got more and more awesome as time went on. All the way to his final days, Elvis was still putting on the most awesome shows of his career in that incredible style. Elvis certainly lived and died as a Legend.")

    html section():
        h3("Conclusion")
        p("Elvis Presley was a style icon. He changed his style over the years, but he always looked awesome. He was a true legend and he will always be remembered as one of the greatest musicians of all time.", style="padding-bottom: 20px;")
    
    h2("Elvis Presley is the King of Rock and Roll!", style="text-align: center; color : gold; background-color: black; padding: 10px;")

    p("page by Josiah Hands", style="font-size: 0.7em;")
    p("josiahwhands@gmail.com", style="font-size: 0.7em;")

    pasteBody()
    
    
    








# write file

writeFile("Index.html", $page());