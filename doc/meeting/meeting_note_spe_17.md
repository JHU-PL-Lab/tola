# Worklog

1. Integrated actions in enumeration from agreement checking and remove legacy steps on ad-hoc checking, including
- Old code has separate inspectation action to _parse_ artifacts (.h, .so. .ml) into cached json and separate actions to _check_ the parse result. It doesn't align with the agreement philosophy that a checking is a complete action to reading something against some truth.
- Old code has <action>_post as hook trigger to run. The concrete action is registered in the project spec, and can support variant e.g. 

