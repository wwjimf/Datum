# Why Datum? The Configuration Data Challenge

Some of you may know, I'm writing and using a PowerShell module called "[**Datum**](https://github.com/gaelcolas/Datum)" to manage DSC Configuration Data, and raise cattle at work.

I assume you already know a bit about Desired State Configuration, but if it's new or rough, go grab yourself [**The DSC Book**](https://leanpub.com/the-dsc-book) by [Don Jones](https://twitter.com/concentrateddon) & [Missy Januszko](https://twitter.com/thedevopsdiva), which packs all you need to know about **_out-of-the-box_ DSC**, and more.

The following article tries to explain the **DSC Configuration Data** composition challenge that I attempt to solve with Datum.

## Table of Content

1. [Raise Cattle, not pets!](#1-raise-cattle-not-pets)
2. [What does it take to raise cattle?](#2-what-does-it-take-to-raise-cattle)
3. [Why Non-node data is not enough?](#3-why-non-node-data-is-not-enough)
4. [Building Configuration Data Dynamically](#4-building-configuration-data-dynamically)
5. [...Dynamically yes, but from files!](#5-dynamically-yes-but-from-files)
6. [Is that all? What's new?](#6-is-that-all-whats-new)
7. [Conclusion: why Datum?](#7-conclusion-why-datum)

## 1. Raise cattle, not pets!

DSC is a **platform** with a nice way of using a **declarative syntax** to define the **state required** for our infrastructure, offloading the process of making that **transformation** happen to lower levels of **abstraction**; the (theoretically) idempotent **DSC Resources** enacted by the Local Configuration Manager (aka **LCM**).

The [common](https://powershell.org/forums/topic/deal-with-multiple-receipe-versions/) [challenge](https://powershell.org/forums/topic/dsc-chef-and-puppet-starting-the-conversation-anew/) [people face](https://powershell.org/forums/topic/reusable-configuration/) can be summarized like so:
How do you avoid pets with DSC, while staying away from [Partial configurations, its risks](https://stevenmurawski.com/2016/03/dsc-partial-configurations-are-the-devils-workshop/) and [quirks](https://powershell.org/forums/topic/partial-configurations-encrypted-credentials/)?


## 2. What does it take to raise cattle?

When we talk about [raising cattle, no pets](https://www.theregister.co.uk/2013/03/18/servers_pets_or_cattle_cern/), or use the snowflake analogy, we mean we don't want our nodes to be uniquely crafted, shaped over time into a something that can't be concisely defined. We need to build a mould, so that what's molded from it can be reproduced consistently and at low cost.

In terms of configuration management, that means we need to have a definition that can be applied to any number of Node, and give us the same result. In other word, the configuration is generic across multiple nodes.

With DSC, one way to do this could be to create a [**named configuration**](https://docs.microsoft.com/en-us/powershell/dsc/pullclientconfignames), and apply that configuration to a number of Nodes.
That can work, but it makes several assumptions: 
- You have no unique piece of data specific to a node in your configuration (i.e. hostname, certificate, machine specific thumbprint)
- You can't do End-to-end system configuration with one DSC configuration (unique data is usually required for this, like hostname, vm id...)
- All nodes in a 'role' must be identical. They can't, for example, have node-specific certificate for Credential Encryption.

Another way to do this is to **compose** the **Configuration Data** in _roles_ or _components_ in a way that can be re-used across different nodes, while still allowing node-specific information to avoid the limitations of **generic named configurations**.

To my knowledge, this is the **state of the art of DSC Configuration Data** possible with **DSC _out-of-the-box_** (that is, without tooling).
This approach has been brilliantly explained and documented by Missy Januszko in her [DSC Configuration Data layout tips and tricks](https://www.petri.com/dsc-configuration-data-layout-tips-tricks) article.


## 3. Why Non-Node data is not enough?

The approach above only provides access to two types of data that can hardly be mixed together:
- The **Node** Specific Data: e.g. `$Node.nodename`
- The **_Role_** Specific Data: e.g. `$ConfigurationData.DHCPData` 

The problem here is that when accessing a piece of data (the property `$ConfigurationData.DHCPData.FooBar`), it will **always** provide the same result for each and every `$Node`. 

Hear me out.

Yes it's good for cattle, but it's not flexible enough for **most real-life infrastructures**, where the generic information can vary slightly depending on, for instance, the **location** of the Node, the **Environment** it's running in, the **customer** it's targeting, or whatever makes sense in your **_business_ context**.

You can _blend_ the data in DSC Configurations, and DSC Composite Resources, but that's code, and already one abstraction away. Also, it most of the time creates **tight coupling** between the **DSC Composite resource** and the **Infrastructure it's targeted to**.

This could look like the following, in a DSC Composite resource:
```PowerShell
configuration MyConfig {
    Param()
    if($Node.Role -contains 'DHCPData' -and $Node.Customers -eq 'CustomerA') {
        $Domain = $ConfigurationData.customerA.Domain
    }
    else {
        $Domain = $ConfigurationData.DefaultDomain.Domain
    }
    File MyDomainFile {
        Ensure = 'Present'
        DestinationPath = "C:\Domain.txt"
        Contents = "$Domain"
    }
}
```

In this case you can see that the Configuration is tightly coupled with the need for **CustomerA**, and would limit its usefulness when shared publicly.
Another, **bigger**, problem is that the logic of the Configuration Data is already passed down to a lower layer of abstraction.

There's many other ways to achieve this goal, but with native DSC, it'll most likely be a variant of the above.

## 4. Building Configuration Data Dynamically

Many of those not afraid to go **beyond** the _out-of-the-box_ DSC have found ways to build the Configuration Data dynamically, from one or several sources.

What I've seen a few times in the wild, is the `$ConfigurationData` hashtable being **composed before compiling the MOF**, usually done by **custom scripts** pulling data from different systems, usually **databases**, or _REST-like_ services.

The principle works well, but tends to be **tied to the infrastructure** it's used in (the composition being done in the script or database schema, means the _rules_ are _hidden_ in that code, and specific to the _business_ context).

The main **benefit** of this approach is that **relational data is easy to query**. It works great for **reporting**,  **monitoring** and **aggregating with different sources**.
What it's really bad at, however, is making the changes self-documenting, frictionless, versioned, manageable, and with an editing workflow that does not need a custom solution.

In other words, databases (whether relational or not) is a nice storage and querying medium, but **not a good user interface** for reading and **editing configuration data**.
It also relies on technologies that introduce more complexity to the system (i.e. SQL or NoSql databases).

Luckily, there are tested and mature solutions with great user interface to display and manipulate configuration data: **Files** and **Version Control Systems**, such as **git**!


## 5. ...Dynamically yes, but from files!

Despite the risk of losing some of the data querying capabilities (for now), you could move that data into **structured files and folders**, and use a **version control system** to manage the **changes** and enable **collaborative work**. Use git locally and with a git server such as github, VSTS, Gitlab, Bitbucket or the one of your choice and you have a great **collaboration and documentation tool**.

> Technically, the Nodes may not be best managed in files, when you start to have more than a couple of hundreds. Datum can be easily extended to support other _storage_ technologies. 

Make sure **all changes come from this central repository**, and you have a **single source of truth** you can rely and enforce from.

Add **tests**, gates (approvals), controls (code review), workflow around changes/releases, connect to you favorite **CI tool**, and you can continuously improve quality, repeatability and security **building confidence in your system and team** over time, while reducing re-work.

Then assemble those files into the `$ConfigurationData` hashtable you need **and you have it**: An Infrastructure definition composed by **Configuration Data**, and the **DSC Code Constructs** (Configuration, Composite and Resources).

This is a **Policy-Driven Infrastructure**, or known by it's less accurate but more popular term **_Infrastructure as Code_**.

The principle followed here is [**The Release Pipeline Model**](https://aka.ms/TRPM) as written and [presented by Michael Greene](https://channel9.msdn.com/Events/WinOps/WinOps-Conf-2016/The-Release-Pipeline-Model) and Steven Murawski, applied to **Configuration Data**!

> As a side note, if you hear about **Test-Driven Infrastructure** (**TDI**), It's in my opinion the result of the Policy-Driven infrastructure concept, applied with the **Test-Driven Development** (**TDD**) best practice.

## 6. Is that all? What's new?

There's **more** to it, like how to structure your files by optimizing on **change scope**, and flexibility while ensuring you're **not drifting towards a pet factory**, but that's out of scope for now.

No, it's not new at all. Back in **2014**, Steve Murawski, then working for Stack Exchange, led the way by implementing some tooling, and open sourced them on the [PowerShell.Org Github](https://github.com/PowerShellOrg/DSC/tree/development).
This work has been enhanced by Dave Wyatt's contributions, mainly around the Credential store.
After these two main contributors moved on from DSC and Pull Server mode, the project stalled (in the Dev branch), despite its unique value.

I [refreshed this](https://github.com/gaelcolas/DscConfigurationData) to be more geared for PowerShell 5, and updated the dependencies as some projects had evolved and moved to different maintainers, locations, and name.

As I was re-writing it, I found that the version offered a very good way to manage **configuration data**, but in a prescriptive way that was lacking a bit of flexibility for some much needed customisation (layers and ordering). Steve also pointed me to [Chef's Databags](https://docs.chef.io/data_bags.html), and later I discovered [Puppet's Hiera](https://docs.puppet.com/hiera/3.3/complete_example.html), which is where I get most of my inspiration for Datum.
Worth noting that Trond Hindenes has introduced me to the Ansible approach to Roles and Playbook which is also similar (or seem, for the little I know).

## 7. Conclusion: why Datum?

Datum is a PowerShell Module that enables you to easily manage a **Policy-Driven Infrastructure** using **Desired State Configuration** (DSC), by letting you organise the **Configuration Data** in files organised in a hierarchy adapted to your business context, and injecting it into **Configurations** based on the Nodes and the Roles they implement.

This (opinionated) approach allows to raise **cattle** instead of pets, while facilitating the management of Configuration Data (the **Policy** for your infrastructure) and provide defaults with the **flexibility of specific overrides**, per **layers**, based on **your environment**.

The Configuration Data is composed in a customisable hierarchy, where the storage can be using the file system, and the format Yaml, Json, PSD1 allowing all the use of version control systems such as git.


Now if you want to learn how, the best place to start might be the [**Datum**](https://github.com/gaelcolas/Datum) project, or the example of control repository of [DscInfraSample](https://github.com/gaelcolas/DscInfraSample).