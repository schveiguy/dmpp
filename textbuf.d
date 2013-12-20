
/**
 * C preprocessor
 * Copyright: 2013 by Digital Mars
 * License: All Rights Reserved
 * Authors: Walter Bright
 */

module textbuf;

import core.stdc.stdlib;
import core.stdc.string;
import std.stdio;

/**************************************
 * Textbuf encapsulates using a local array as a buffer.
 * It is initialized with the local array that should be large enough for
 * most uses. If the need exceeds the size, it will resize it
 * using malloc() and friends.
 */

//debug=Textbuf;

struct Textbuf(T, string id = null)
{
    this(T[] buf)
    {
        this.buf = buf.ptr;
        this.buflen = cast(uint)buf.length;
    }

    void put(T c)
    {
        if (i == (buflen & ~RESIZED))
        {
            resize(i ? i * 2 : 16);
        }
        buf[i++] = c;
    }

    static if (T.sizeof == 1)
    {
        void put(dchar c)
        {
            put(cast(T)c);
        }

        void put(const(T)[] s)
        {
            size_t newlen = i + s.length;
            auto len = buflen & ~RESIZED;
            if (newlen > len)
                resize(newlen <= len * 2 ? len * 2 : newlen);
            buf[i .. newlen] = s[];
            i = cast(uint)newlen;
        }
    }

    /******
     * Use this to retrieve the result.
     */
    T[] opSlice(size_t lwr, size_t upr)
    {
        assert(lwr < (buflen & ~RESIZED));
        assert(upr <= (buflen & ~RESIZED));
        assert(lwr <= upr);
        return buf[lwr .. upr];
    }

    T[] opSlice()
    {
        assert(i <= (buflen & ~RESIZED));
        return buf[0 .. i];
    }

    T opIndex(size_t i)
    {
        assert(i < (buflen & ~RESIZED));
        return buf[i];
    }

    void initialize() { i = 0; }

    T last()
    {
        assert(i - 1 < (buflen & ~RESIZED));
        return buf[i - 1];
    }

    T pop()
    {
        assert(i - 1 < (buflen & ~RESIZED));
        return buf[--i];
    }

    @property size_t length()
    {
        return i;
    }

    void setLength(size_t i)
    {
        assert(i < (buflen & ~RESIZED));
        this.i = cast(uint)i;
    }

    /**************************
     * Release any malloc'd data.
     */
    void free()
    {
        debug(Textbuf) buf[0 .. buflen & ~RESIZED] = 0;
        if (buflen & RESIZED)
            .free(buf);
        this = this.init;
    }

  private:
    T* buf;
    uint buflen;
    enum RESIZED = 0x8000_0000;         // this bit is set in buflen if we control the memory
    uint i;

    void resize(size_t newsize)
    {
        //writefln("%s: oldsize %s newsize %s", id, buf.length, newsize);
        void* p;
        if (buflen & RESIZED)
        {
            /* Prefer realloc when possible
             */
            p = realloc(buf, newsize * T.sizeof);
            assert(p);
        }
        else
        {
            p = malloc(newsize * T.sizeof);
            assert(p);
            memcpy(p, buf, i * T.sizeof);
            debug(Textbuf) buf[0 .. buflen] = 0;
        }
        buf = cast(T*)p;
        buflen = newsize | RESIZED;
    }
}

unittest
{
    char[1] buf = void;
    auto textbuf = Textbuf!char(buf);
    textbuf.put('a');
    textbuf.put('x');
    textbuf.put("abc");
    assert(textbuf.length == 5);
    assert(textbuf[1..3] == "xa");
    assert(textbuf[3] == 'b');
    textbuf.pop();
    assert(textbuf[0..textbuf.length] == "axab");
    textbuf.setLength(3);
    assert(textbuf[0..textbuf.length] == "axa");
    assert(textbuf.last() == 'a');
    assert(textbuf[1..3] == "xa");
    textbuf.put(cast(dchar)'z');
    assert(textbuf[] == "axaz");
    textbuf.initialize();
    assert(textbuf.length == 0);
    textbuf.free();
}
