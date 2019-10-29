---
@snap[north span-100]
### ARM Template Validation
### using PowerShell Classes and Pester
@snapend

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
+++

@snap[north-west]
#### Components of an ARM template
@snapend

@snap[west span-90 text-07]
- Resources 
  - The things which actually get deployed
- Parameters
  - The values you pass in when deploying the template
- Variables
  - The values calculated within the template, sometimes using user input
- Outputs
  - The values passed out of a template for use elsewhere
- Functions
  - Custom functions you can write to use in your templates
@snapend

Note:
-Resources – Storage accounts, VMs, other Azure stuff. Required for a valid template.
-Parameters – names, locations, passwords, anything that can change per deployment.
-Variables – doing stuff with user input usually or a value that might want to be used in multiple places
-Outputs – generated URLs, references to internal values, other such stuff. For use in other nested templates or the rest of the pipeline
-Functions – Useful for ensuring a common format for generated names, some restrictions on what you can use inside it. 

---

@snap[north-west]
#### Why should we validate them?
@snapend

@snap[west span-100]
- No one wants to break production
- CI/CD is big part of many application deployments
- Catch errors earlier
@snapend

---

@snap[north-west]
#### How do people currently validate them?
@snapend

@snap[west span-100]
- Test-AzDeployment/Test-AzResourceGroupDeployment
- Pester
- DevSecOps Kit for Azure (AzSK)
@snapend

Note:

Various links for blog posts and pester scripts to test templates:

- https://azure.microsoft.com/en-gb/resources/videos/azure-friday-getting-started-with-the-secure-devops-kit-for-azure-azsk/
- https://dscottraynsford.wordpress.com/2018/10/13/use-pester-to-test-azure-resource-manager-templates-for-best-practices
- https://blog.tyang.org/2018/09/12/pester-test-your-arm-template-in-azure-devops-ci-pipelines/
- https://github.com/sam-cogan/sessions/tree/master/PesterTesting
- https://4bes.nl/2019/04/11/armhelper-a-module-to-help-create-arm-templates/
- https://github.com/Azure/azure-quickstart-templates/tree/master/test

---

@snap[midpoint]
### Demo - Current ARM Validation
@snapend

---

@snap[north-west]
#### How can we use classes to help?
@snapend

@snap[west span-100]
- Classes allow building data structures
- ARM is a programming language so we can build an AST
- Navigating the structure of an object is easier than text
@snapend

Note:
PowerShell can navigate text pretty easily but it'll take a lot of regex and a lot of edge cases, better to use the built in tools to make those into objects, then we can navigate those in a few ways.

ARM is sort of a programming language, it has a lot of the features of one, and as it follows a pretty strict structure we can build out a tree of how the various elements are related to other elements and navigate it in a few ways. An Abstract Syntax Tree is a way of representing how the various elements in a script, or line of code, relate to each other and what types they are.

---

@snap[north-west]
#### Tangent: Abstract Syntax Tree?
@snapend

@snap[west span-50 text-06]
A tree representation of the abstract syntactic structure of source code written in a programming language.
Each node is a construct in the code, e.g. command, parameter, if statement, pipeline.
Punctuation is rarely part of an AST as it usually isn’t relevant.
@snapend

@snap[east span-40]
![AST](https://upload.wikimedia.org/wikipedia/commons/c/c7/Abstract_syntax_tree_for_Euclidean_algorithm.svg)
@snapend

---

@snap[midpoint]
### Demo - ASTs
@snapend

---

@snap[north-west]
#### How do we bring together AST and PowerShell Classes?
@snapend

@snap[west span-100]
- ASTs work best with a hierarchical structure
- ARM templates have a well defined structure (mostly)
- We can get a lot of initial validation without diving too deep
- It can be made to cover areas that Test-AzDeployment doesn't currently
- There's a lot of scope for doing more than simple "is this a valid template"
@snapend

---

@snap[midpoint]
### Demo - ArmTemplateValidation Module
@snapend

---

@snap[north-west]
#### What else can we do with this?
@snapend

@snap[west span-100 text-08]
- Write more comprehensive validation tests
- Combine it with the other methods
- Build extra tools on top of this like visualisation
- Whatever other things you can think of when the template and all it's children are objects
@snapend

Note:

You always need more validation tests, and should treat templates like any other code: When you find a bug then write another test(s) to catch it and add it to your test suite.
Comprehensive tests like "Do all my resources match this name format?", "Do I have any storage accounts with more than 24 characters in the name? Any upper case?"
Because the templates are aware of how they are related to other templates and elements there's already a lot of validation built in, like parameters being passed to linked templates correctly (and the values go across too for further use).
The visualisation I've built with PSGraph is pretty simple and could do with a lot more work but isn't a priority right now, fixing layout and sizes etc would be a good place to start at some point.
One thing I want to do is take some these features I've built and feed them back into the ARM tools extension for VS Code since I borrowed their parser implementation. The main one is the handling of values between templates but not 100% sure how to handle that, plus it means learning typescript more which I don't have time for right now.

---

## Questions?

---

@snap[north-west]
### Slides and Stuff
@snapend

@snap[west span-100]
- Slides on Github: github.com/chrislgardner/presentations
- ArmTemplateValidation: github.com/chrislgardner/ArmTemplateValidation
- Twitter: @halbaradkenafin
- Slack/Discord: @halbarad
- aka.ms/psslack
- aka.ms/psdiscord
@snapend

---
