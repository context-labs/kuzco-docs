# Kuzco Operators Documentation

Welcome to the official documentation for Kuzco operators! This documentation site is built with [Mintlify](https://mintlify.com).

## 🚀 Quick Start

Install the [Mintlify CLI](https://www.npmjs.com/package/mintlify) to preview the documentation changes locally. To install, use the following command:

```
npm i -g mintlify
```

Run the following command at the root of your documentation (where mint.json is):

```
mintlify dev
```

## 😎 Publishing Changes

Install our Github App to auto propagate changes from your repo to your deployment. Changes will be deployed to production automatically after pushing to the default branch. Find the link to install on your dashboard. 

#### Troubleshooting

- Mintlify dev isn't running - Run `mintlify install` it'll re-install dependencies.
- Page loads as a 404 - Make sure you are running in a folder with `mint.json`

## 📁 Project Structure

```
/
├── getting-started/     # Getting started guides
├── installation/        # Installation guides for different platforms
├── guides/             # Advanced guides and tutorials
├── community/          # Community resources and support
├── images/            # Images used in documentation
├── logo/              # Logo files
├── snippets/          # Reusable documentation snippets
└── mint.json          # Mintlify configuration
```

## 🤝 Contributing

We welcome contributions to improve the documentation! Please feel free to submit pull requests or open issues.

## 📞 Support

For support, join our [Discord community](https://discord.gg/kuzco) or visit our [support page](https://docs.devnet.inference.net/community/support).

## Workflow

This documentation has *many, many* code blocks.
Code blocks have a bad rep, for good reason.
* They are often out-of-sync, and broken.  
* It's a chore to check them.
* Sometimes examples are split across blocks and assembling them is time-consuming and error prone
* AI is going to catch some things, but not necessarily the behavior of the endpoints the examples call or the behavior of the libraries used. So it's not a silver bullet (speaking from experience).

There isn't good support for code block checking in mintlify, so I made a tool to do that.
It's a python script under `test/` called `code_blocks.py`.
The tool has two modes:
1. Extract all code blocks
2. Import all code blocks

The workflow is this:
1. Extract all code blocks
2. Run the code blocks that have changed
3. Directly update the extracted code blocks, if desired
4. Import all code blocks to put them back into the docs

Again - you can update the extracted code blocks directly.  When you run import, the edit code blocks get put back exactly where they belong.
However, each code block requires a "metadata" tag on the preceeding line, or it won't get picked up.

## Commands

This writes all the code blocks to individual files in the `test/code` directory.
```
python test/code_blocks.py --extract_code_blocks
```

Then, you can edit each of the files.  To yeet the code blocks back into the documentation, run:
```
python test/code_blocks.py --import_code_blocks
```

It's bi-directional! So, if you edit the extracted code block, it will write it back to the documentation when you run the import code blocks command.

## New Code Blocks

Any time you add a new code block, in the line immediately above it, *always* add a "metadata" tag.
```
<Metadata text="function_calling/import_openai" />
```

The value of "text" is the where the code block gets written to and read from (with the appropriate file extension based on the language).

If a series of code blocks should be run together, then you can indicate this by adding a special part to the "text" value:
```
<Metadata text="function_calling/import_openai[series=example_1]" />
```

Then, all code blocks that share the `[series=example_1]` will be written to a single file under `test/code_blocks/series`, for convenience.

**Note**: These "series" files do not support bi-directional editing, they are not imported back into the documentation when you run `--import-code-blocks`. 

They are just for convenience.


