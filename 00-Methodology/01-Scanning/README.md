## 01 - Scanning
Assuming all pre-requisite due diligence and research regarding the target(s) has been completed, it's time to scan for possible attack vectors.
<br>
* **WEB PAGES**:
  - [ ] Login panels and admin pages (injections, default creds, versions, etc.)
  - [ ] Request/Contact Forms, Comment boxes (anything that allows user input)
  - [ ] Insecure parameter design (Path traversal, Direct object references, etc.)
  - [ ] Information disclosure (Dev tools, page source, application stack, versions, etc.)
* **IP ADDRESS**:
  - [ ] Port scan
  - [ ] Operating System
  - [ ] Latest patch vs Exploit creation
  - [ ] Virtual Host Check
  - [ ] Information disclosure
* **USERS**:
  - [ ] Emails
  - [ ] Lateral movement by network connections
  - [ ] Social Media
  - [ ] Profiling & Preferences (create custom dictionaries)
  - [ ] Social Engineering (Main information gathering -> Sock puppets) 
---
### CONTENT
| Script Name | Description |
| --- | --- |
| `scorpio_scan.sh` | My automated version of running a full-scale scan on a target IP |
