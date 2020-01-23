This project contains Smart renaming functions.

The concept is to be able to merge master data keys, such as Item ID, Customer Account, Vendor account etc etc.

Problem occurs when any of the renaming causes index violation.  Standard AX rename then errors.

Smart renaming investigates alle affected tables and advices the user if the rename would violate index unique constraints.
On index unique constraint violation, the user can but the affected tables into a list of Black and While listed tables.
White listed tables: If a unique constraint is found, the offending records are removed before rename occurs without any prompt.
Black listed tables: If a unique constraint is found, the smart renaming reports an error and aborts.
Unlisted tables: If a unique constraint is found, user is prompted and the offending records are removed before rename occurs if user opts to continue.  Otherwise rename errors and aborts.

BE AWARE: This solution removes and changes data.  Be absolutely sure the result is desired, and do so by testing in a seperate system first.

DISCLAIMER: Any use of this code is on the users responsibility.  I offer no guarantee or liability!

Happy renaming...