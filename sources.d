
/**
 * C preprocessor
 * Copyright: 2013 by Digital Mars
 * License: All Rights Reserved
 * Authors: Walter Bright
 */

// Deals with source file I/O

module sources;

import std.file;
import std.path;
import std.stdio;
import std.string;

import main;

/*********************************
 * Things to know about source files.
 */

struct SrcFile
{
    string filename;            // fully qualified file name
    ustring contents;           // contents of the file
    ustring includeGuard;       // macro #define used for #include guard
    bool once;                  // set if #pragma once set
    bool doesNotExist;          // file does not exist

    static SrcFile* lookup(string filename)
    {
        __gshared SrcFile[string] table;

        SrcFile sf;
        sf.filename = filename;
        auto p = filename in table;
        if (!p)
        {
            table[filename] = sf;
            p = filename in table;
        }
        return p;
    }

    /*******************************
     * Read a file and set its contents.
     */
    bool read()
    {
        if (doesNotExist)
            return false;

        if (contents)
            return true;                // already read

        bool result = true;
        try
        {
            contents = cast(ustring)std.file.read(filename);
        }
        catch (FileException e)
        {
            result = false;
            doesNotExist = true;
        }
        return result;
    }
}

/*********************************
 * Search for file along paths[].
 * Cache results.
 * Input:
 *      filename        file to look for
 *      paths[]         search paths
 *      starti          start searching at paths[starti]
 * Output:
 *      foundi          paths[index] is where the file was found,
 *                      paths.length if not in paths[]
 * Returns:
 *      fully qualified filename if found, null if not
 */

SrcFile* fileSearch(string filename, string[] paths, int starti, out int foundi)
{
    foundi = paths.length;

    filename = strip(filename);
    SrcFile* sf;

    if (isRooted(filename))
    {
        sf = SrcFile.lookup(filename);
        if (!sf.read())
            return null;
    }
    else
    {
        foreach (key, path; paths[starti .. $])
        {
            auto name = buildPath(path, filename);
            sf = SrcFile.lookup(name);
            if (sf.read())
            {   foundi = key;
                goto L1;
            }
        }
        return null;
    }
 L1:
    filename = buildNormalizedPath(sf.filename);
    if (filenameCmp(filename, sf.filename))
    {   // Cache the normalized file name as a clone of the original unnormalized one
        auto sf2 = SrcFile.lookup(filename);
        sf2.contents = sf.contents;
        sf2.includeGuard = sf.includeGuard;
        sf2.once = sf.once;
        sf2.doesNotExist = sf.doesNotExist;
        sf = sf2;
    }
    return sf;
}

