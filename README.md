# A Debugger for Object::Pad

Like many other modules available from [CPAN](https://www.cpan.org/),
[Object::Pad](https://metacpan.org/pod/Object::Pad) adds object
oriented (OO) syntax to the [Perl](https://perl.org) programming
language.

What makes it special is that it also serves as a test bed for the
[Corinna project](https://github.com/Ovid/Cor) to add OO syntax to the
Perl core.

On the downside for playing around with the idea is that your usual
Perl tools for data inspection like the [Perl
debugger](https://perldoc.perl.org/perldebug) can not inspect its
objects easily.  This hack tries to work around the issue.

It is a hack because the Perl debugger isn't actually designed to be
extended easily.  But Perl being Perl, there's always a way.

## Usage

Drop the file lib/Devel/opaddb.pm within your `@INC` path, so that
Perl can find it as module C<Devel::opaddb>.  Then start the debugger
by enabling this module as debugger:
```
   perl -d:opaddb your/program.pl
```

## COPYRIGHT AND LICENSE

COPYRIGHT 2021-2022 Harald Jörg

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.
