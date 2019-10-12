---?image=2019-10-12-PS-Saturday-Paris/assets/img/Title.jpg
@snap[north span-100]
### ARM Template Validation
### using PowerShell Classes and Pester
@snapend
---?image=2019-10-12-PS-Saturday-Paris/assets/img/Sponsors.jpg

---
@snap[north span-100]
#### $Env:USERNAME = 'Chris Gardner'
@snapend

- PowerShell user for ~6 years
- Too many side projects
- Work a lot with Azure and DSC
- I have stickers for anyone who wants some
- Join Slack/Discord: aka.ms/psslack or aka.ms/psdiscord

---
@snap[north span-100]
#### Agenda
@snapend

@snap[west span-80]
@ul[list-spaced-bullets]
- What are ARM templates?
- Why should we validate them?
- How do people currently validate them?
- How can we use classes to help?
- What else can we do with this?
@ulend
@snapend

---
@snap[north-west]
#### What are ARM templates?
@snapend

@snap[west span-80]
- Declarative format for Azure infrastructure
- Well documented schema that doesn't change often
- 5 major components of a template
@snapend
---

@snap[north-west]
#### Components of an ARM template
@snapend

---

@snap[north-west]
#### Why should we validate them?
@snapend

@snap[south span-100 text-06]
[Click here to jump straight into the interactive feature guides in the GitPitch Docs @fa[external-link]](https://gitpitch.com/docs/getting-started/tutorial/)
@snapend

---

@snap[north-west]
#### How do people currently validate them?
@snapend

---

@snap[north-west]
#### How can we use classes to help?
@snapend

---

@snap[north-west]
#### What else can we do with this?
@snapend

---
```sql zoom-18
CREATE TABLE "topic" (
    "id" serial NOT NULL PRIMARY KEY,
    "forum_id" integer NOT NULL,
    "subject" varchar(255) NOT NULL
);
ALTER TABLE "topic"
ADD CONSTRAINT forum_id
FOREIGN KEY ("forum_id")
REFERENCES "forum" ("id");
```

@snap[south span-100 text-gray text-08]
@[1-5](You can step-and-ZOOM into fenced-code blocks, source files, and Github GIST.)
@[6,7, zoom-13](Using GitPitch live code presenting with optional annotations.)
@[8-9, zoom-12](This means no more switching between your slide deck and IDE on stage.)
@snapend
