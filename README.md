<!-- markdownlint-disable MD032 MD033-->
# **Fadestorm Consumable Manager**

<p align="center">
  <a href="https://github.com/Josee9988/project-template/generate">
    <img width="100%" src="res/display-screenshot.png" alt="@Josee9988/project-template's">
  </a>
  <br>
</p>

---


**Fadestorm Consumable Manager** is a [WeakAura](https://www.curseforge.com/wow/addons/weakauras-2) for *World of Warcraft: Classic* written in Lua. It monitors the stock, application, and duration of a list of consumables & quantities, provided from a user-defined profile in the custom options.

## ◆ Overview ◆

* Indicates which consumables to bring according to your selected profile.
* Shows if you have enough supply, or if the item is stored elsewhere (bank, mail, etc)
* Marks whether a consumable's buff is missing, or is running low.
* Attaches to the bottom of the character frame; only displaying when open.
* Let's you customize when items show or hide through user-defined 'rules'.

---

## ▲ Usage ▲

1. Profiles
    - Create a new profile with a memorable name, e.g. `Myhunter: AQ40`
    - *Note: The loaded profile is always the first profile in the list. To re-arrange profiles, click the △/▽ Arrows.*
    - For each profile, provide names of items and the desired quantity to be brought for each item. *e.g. `Major Mana Potion`, `10`*
2. Display
    - For each of the profile's consumables (if not hidden by a rule) will have one of each symbol:
        * **Quantity**
            - | ![OK](https://img.shields.io/badge/OK-green) | Item supply in bags meets your preferences.
            - | ![+?](https://img.shields.io/badge/+%3F-yellow) | Item supply is met, but items are outside your bags. By default, your bank. *Note: If [TSM](https://tradeskillmaster.com/) is installed, 'outside your bags' includes mailbox, other characters, etc. For Bind-on-Pickup items, only your bags & bank are checked.*
            - | ![NO](https://img.shields.io/badge/NO-red) | Item supply is not met.
        * **Application**
            - | ![--](https://img.shields.io/badge/----%20-white) | Item's buff is applied with a healthy duration, *or has no associated buff*.
            - | ![<<](https://img.shields.io/badge/%3C%3C-tan) | Item's buff is applied, but is considered to be low duration *(adjustable by the `low duration` slider)*.
            - | ![>>](https://img.shields.io/badge/%3E%3E-orange) | Item's buff is not applied.
3. Rules
    * **Rules allow fine control over when items are to-be hidden**, as [large volumes of tracked items can yield an unwieldy display](res/ruleless-screenshot.png) otherwise.
    * Rules consist of a list of `conditions`, each of which is evaluated against an item. If all conditions evaluate to `true` for a given item, *that item will be hidden from the display at that moment*.
    * *Note: A rule can be enabled/disabled at any time using the Rule Enabled checkbox.*
    * Conditions
        - *A condition can be negated/inverted using the `Negate Condition` checkbox.*
        - List of available conditions:
            * | `In Dungeon/Raid` | `true` if the player is currently in a dungeon/raid.
            * | `In Rested Area` | `true` if the player is in a major city or inn.
            * | `Item Yields Buff` | `true` if the item can apply a long-standing aura. Items whose buffs cannot be continuously refreshed are not included (e.g. `Mighty Rage Potion`).
            * | `Item In Inventory` | `true` if the player's bags contain at least one of the item.
            * | `Item Supply Healthy` | `true` if the player's bags meet the preferred supply of the item.
            * | `Player Max Level` | `true` if the player's character is max level.
            * | `Item Is Soulbound` | `true` if the item cannot be traded.








1. To create a new repository from this template, **[generate your new repository from this template](https://github.com/Josee9988/project-template/generate)**;
for more information or guidance, follow the [GitHub guide](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/creating-a-repository-from-a-template).
2. Install the [🤖 used GitHub bots](https://github.com/Josee9988/project-template#-used-github-bots) (recommended)
3. Clone your new repository **[generated from this template](https://github.com/Josee9988/project-template/generate)** and `cd` into it.
4. **Execute** the `SETUP_TEMPLATE.sh` shell script to **customize** the files with your data.

    ```bash
    bash SETUP_TEMPLATE.sh
    ```

    Or

    ```bash
    ./SETUP_TEMPLATE.sh
    ```

    Additionally, watch *[this video](https://asciinema.org/a/425259)* to see **how to execute the script** or use *`bash SETUP_TEMPLATE.sh --help`* to obtain some extra information.

    If the automatic detection of the username, project name or email is NOT correct, please post an issue, and you can **manually correct** them using the optional arguments like: *`bash SETUP_TEMPLATE.sh --username=whatever --projectName=whatever --email=whatever --projectType=whatever`*

5. **Review** every single file and **customize** it as you like.
6. Build your project. 🚀

⚠️ _Customize every file to fit your requirements_ ⚠️

---

## ✦ Configuration ✦

1. A **`SETUP_TEMPLATE.sh`** script that **MUST be executed right when you clone your repository**.
The script will customize all the data with yours in all the files.

   1. A README template file with a default template to start documenting your project. (it includes personalized badges and text with your project details)
   2. A CHANGELOG template file based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
   3. An [issue_label_bot.yaml](/.github/issue_label_bot.yaml) file to use the issue adder GitHub bot. [Activate it or check its documentation](https://github.com/marketplace/issue-label-bot).
   4. A [config.yml](/.github/config.yml) file to modify multiple bot's behaviours.
   5. A [settings.yml](/.github/settings.yml) file to use the popular settings GitHub bot. [Activate it or check its documentation](https://probot.github.io/apps/settings/).
   6. A [CONTRIBUTING](/.github/CONTRIBUTING.md) explaining how to contribute to the project. [Learn more with the GitHub guide](https://docs.github.com/en/github/building-a-strong-community/setting-guidelines-for-repository-contributors).
   7. A [SUPPORT](/.github/SUPPORT.md) explaining how to support the project. [Learn more with the GitHub guide](https://docs.github.com/en/github/building-a-strong-community/adding-support-resources-to-your-project).
   8. A [SECURITY](/.github/SECURITY.md) with a guide on how to post a security issue. [Learn more with the GitHub guide](https://docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository).
   9. A [CODEOWNERS](/.github/CODEOWNERS) with the new user as the principal owner. [Learn more with the GitHub guide](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/about-code-owners).
   10. A [CODE_OF_CONDUCT](/.github/CODE_OF_CONDUCT.md) with a basic code of conduct. [Learn more with the GitHub guide](https://docs.github.com/en/github/building-a-strong-community/adding-a-code-of-conduct-to-your-project).
   11. A [PULL_REQUEST_TEMPLATE](/.github/pull_request_template.md) with a template for your pull request that closes issues with keywords. [Learn more with the GitHub guide](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/creating-a-pull-request-template-for-your-repository).
   12. Multiple [issues templates](/.github/ISSUE_TEMPLATE). [Learn more with the GitHub guide](https://docs.github.com/en/github/building-a-strong-community/configuring-issue-templates-for-your-repository).
         1. A [config.yml](/.github/ISSUE_TEMPLATE/config.yml) with the config and information about the issue templates.
         2. A [Blank issue template](/.github/ISSUE_TEMPLATE) with the super basic stuff, all the issues should contain.
         3. A [Bug issue template](/.github/ISSUE_TEMPLATE/1-bug-report.md).
         4. A [Failing test issue template](/.github/ISSUE_TEMPLATE/2-failing-test.md).
         5. A [Documentation issue template](/.github/ISSUE_TEMPLATE/3-docs-bug.md).
         6. A [Feature request issue template](/.github/ISSUE_TEMPLATE/4-feature-request.md).
         7. An [Enhancement request issue template](/.github/ISSUE_TEMPLATE/5-enhancement-request.md).
         8. A [Security report issue template](/.github/ISSUE_TEMPLATE/6-security-report.md).
         9. A [Question or support issue template](/.github/ISSUE_TEMPLATE/7-question-support.md).

---

### ✪ Screenshots ✪

Files that will get removed after the execution of `SETUP_TEMPLATE.sh` are not shown! 🙈

```text
.
├── CHANGELOG.md
├── .github
│   ├── CODE_OF_CONDUCT.md
│   ├── CODEOWNERS
│   ├── config.yml
│   ├── CONTRIBUTING.md
│   ├── FUNDING.yml
│   ├── issue_label_bot.yaml
│   ├── ISSUE_TEMPLATE
│   │   ├── 1-bug-report.md
│   │   ├── 2-failing-test.md
│   │   ├── 3-docs-bug.md
│   │   ├── 4-feature-request.md
│   │   ├── 5-enhancement-request.md
│   │   ├── 6-security-report.md
│   │   ├── 7-question-support.md
│   │   └── config.yml
│   ├── ISSUE_TEMPLATE.md
│   ├── pull_request_template.md
│   ├── SECURITY.md
│   ├── settings.yml
│   └── SUPPORT.md
├── .gitignore
└── README.md

2 directories, 22 files
```

---

## ➤ Import String ➤

* After **[generating your new repo with this template](https://github.com/Josee9988/project-template/generate)**, make sure to, right after you clone it, run the script `SETUP_TEMPLATE.sh`.

* Then, after 'cloning' the repository you will be presented with all the files modified with your project details and information. It is essential to **manually review every file** to check if it fits your requirements and performs any necessary changes to customize the project as you want.

* If you are using **Windows** and you don't know how to execute the `SETUP_TEMPLATE.sh` script:
  1. Install **[git for Windows](https://git-scm.com/download/win)**.
  2. Right-click on the git repository folder and click "*git bash here*".
  3. Then just perform *`bash SETUP_TEMPLATE.sh`* **or** *`chmod u+x SETUP_TEMPLATE.sh && ./SETUP_TEMPLATE.sh`*.

## ✎ Notes ✎

These are recommended bots that are prepared and configured for this template. If you install them, your coding experience will probably be much better.
We sincerely recommend at least installing the [issue label bot](https://github.com/marketplace/issue-label-bot) as this bot is the one that adds all the labels used in the issue templates.

1. The `issue_label_bot.yaml` file depends on the **[issue label bot](https://github.com/marketplace/issue-label-bot)** (✓ highly recommended).
2. The `settings.yml` file depends on the **[settings label bot](https://probot.github.io/apps/settings/)** (optional).
3. The `config.yml` file depends on the bot **[welcome bot](https://probot.github.io/apps/welcome/)** and **[to-do bot](https://probot.github.io/apps/todo/)** (optional).

---

## ♺ Dependencies ♺

A couple of screenshots to delight you before you use this template.

### 🔺 All the issue templates

<p align="center">
  <img width="70%" height="70%" src="https://i.imgur.com/SDJixBz.png" alt="All the issue templates.">
</p>

### 🔻 An issue template opened

<p align="center">
  <img width="70%" height="70%" src="https://i.imgur.com/r5AiLWu.png" alt="Bug issue template opened.">
</p>

### 📘 The README template

Badges and texts will be replaced with your project details!

<p align="center">
  <img width="70%" height="70%" src="https://i.imgur.com/dKKh53K.png" alt="README.md template.">

  Or watch [this video](https://gifs.com/gif/josee9988-s-readme-md-MwO5E3) to see the whole README template.
</p>

### 🔖 The labels for your issues

If the bot [probot-settings](https://probot.github.io/apps/settings/) is not installed you will not have these beautiful labels! (there are more issue labels than in the image!)

<p align="center">
  <img width="70%" height="70%" src="https://i.imgur.com/dS91k6R.png" alt="LABELS">
</p>

### 📝 The CHANGELOG template

(project name and project type will be replaced with yours)

<p align="center">
  <img width="70%" height="70%" src="https://i.imgur.com/ScWgQKI.png" alt="CHANGELOG.md template.">
</p>

### 🛡️ Security policy

<p align="center">
  <img width="70%" height="70%" src="https://i.imgur.com/ArwDQTi.png" alt="Security issue.">
</p>

### 💼 Community profile at 100%

<p align="center">
  <img width="70%" height="70%" src="https://i.imgur.com/kRt3lPs.png" alt="Community profile.">
</p>

---

## 🕵️ **Extra recommendations**

For the proper maintenance of the CHANGELOG.md, we recommend this [VSCode extension](https://github.com/Josee9988/Changelog-and-Markdown-snippets)
and the read and understanding of the [keep a changelog guide](https://keepachangelog.com/en/1.0.0/).
Please read and comment about it in this [dev.to post](https://dev.to/josee9988/the-ultimate-github-project-template-1264).
We also recommend installing all the [used bots](https://github.com/Josee9988/project-template#-used-github-bots).

## 💉 **Project tests**

If you want to improve the development of this project, you must, after changing or improving whatever, run the project's tests to prove that they are working.

To do so:

```bash
bash tests/TESTS_RUNNER.sh
```

---

## 🍰 **Supporters and donators**

<a href="https://github.com/Josee9988/project-template/generate">
  <img alt="@Josee9988/project-template's brand logo without text" align="right" src="https://i.imgur.com/3qK1sie.png" width="18%" />
</a>

We are currently looking for new donators to help and maintain this project! ❤️

By donating, you will help the development of this project, and *you will be featured in this project's README.md*, so everyone can see your kindness and visit your content ⭐.

<a href="https://github.com/sponsors/Josee9988">
  <img alt="project logo" src="https://img.shields.io/badge/Sponsor-Josee9988/project template-blue?logo=github-sponsors&style=for-the-badge&color=red">
</a>

---

## 🎉 Was the template helpful? Please help us raise these numbers up

[![GitHub's followers](https://img.shields.io/github/followers/Josee9988.svg?style=social)](https://github.com/Josee9988)
[![GitHub stars](https://img.shields.io/github/stars/Josee9988/project-template.svg?style=social)](https://github.com/Josee9988/project-template/stargazers)
[![GitHub watchers](https://img.shields.io/github/watchers/Josee9988/project-template.svg?style=social)](https://github.com/Josee9988/project-template/watchers)
[![GitHub forks](https://img.shields.io/github/forks/Josee9988/project-template.svg?style=social)](https://github.com/Josee9988/project-template/network/members)

Enjoy! 😃

> ⚠️ Remember that this template should be reviewed and modified to fit your requirements.
> The script **SETUP_TEMPLATE.sh** should be executed right when you clone your new repository generated from [here](https://github.com/Josee9988/project-template/generate).
> There will be files that will need *manual revision* ⚠️

_Made with a lot of ❤️❤️ by **[@Josee9988](https://github.com/Josee9988)**_
