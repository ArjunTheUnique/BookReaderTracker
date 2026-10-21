# SECTION 6 — MODULE TECHNICAL APPENDIX

| Technical Term / Syntax Used | Plain-English Definition | 1-Sentence Everyday Analogy |
|---|---|---|
| AES-256-GCM | A strong, standard encryption method that also detects tampering. | A bank-vault lock that tells you if anyone touched the door. |
| Atomic replace | A swap that either happens completely or not at all. | A bank transfer that moves the money both ways or not at all. |
| Base64 | A way to write raw bytes using only ordinary text characters. | Packing odd-shaped items into standard boxes so they travel safely. |
| Checksum | A short fingerprint of a file, used to prove it was not damaged. | Counting the pages of a book to be sure none were torn out. |
| Cipher port | The injectable boundary behind which the crypto library lives. | A specialist you phone to lock the box, rather than doing it yourself. |
| Control/data split | Decisions live apart from transport and storage. | The signal operator decides; the rails carry the train. |
| Data pipe (D6) | The plumbing that snapshots, encrypts and writes the file. | The conveyor that carries the sealed envelope to the drawer. |
| Error shape (E1–E9) | The one agreed object every failure is reported in. | A standard incident form, the same fields every time. |
| FileVault port | The injectable boundary behind which file IO lives. | A hatch through which you pass the envelope to the filing clerk. |
| LibraryVaultPort | M6's declared seam onto M1 for snapshot and replace. | A menu of what you may ask the librarian for. |
| Passphrase | A user-chosen secret that unlocks the backup, never stored. | The combination to your own safe, kept only in your head. |
| Schema version | The number naming which version of the data layout a file speaks. | A form's edition number so both sides know the revision. |
| Validate-before-overwrite (S8) | Checking a backup is good before touching live data. | Tasting the milk before pouring out the fresh bottle. |
| `.rtbk` | The single encrypted backup file the user owns. | A sealed envelope of photocopies kept in your own drawer. |
| BACKUP_INVALID (E9) | The backup was refused: wrong passphrase, damaged, or unknown version. | The bank refusing a tampered cheque rather than cashing it. |
