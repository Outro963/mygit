// MyGit - skeleton only.
//
// WHAT THIS FILE IS:  a placeholder so that `build.ps1` has something to compile
//                     on Week 1 Day 4, plus a starting point for argv handling.
//
// WHAT THIS FILE IS NOT:  an implementation. Every command below is a stub that
//                     must be written BY YOU (see 计划-C++版16周.md, Weeks 2-6).
//                     If you'd rather start truly from scratch, delete this file
//                     and write your own main.cpp -- that is the better exercise.
//
// Week 1 Day 5 task: replace this dispatch with your own design.

#include <iostream>
#include <string>
#include <vector>

namespace {

void print_usage() {
    std::cout <<
        "usage: mygit <command> [<args>]\n"
        "\n"
        "commands:\n"
        "  init                     create an empty .mygit repository\n"
        "  hash-object [-w] <file>  compute (and optionally store) a blob hash\n"
        "  cat-file -p <hash>       pretty-print an object\n"
        "  add <path>...            stage file contents into the index\n"
        "  status                   show working tree / index / HEAD state\n"
        "  write-tree               write the index out as a tree object\n"
        "  commit -m <message>      record the staged tree as a new commit\n"
        "  log                      walk commit history from HEAD\n"
        "  branch [<name>]          list or create branches\n"
        "  checkout <name>          switch branches\n";
}

int not_implemented(const std::string& command) {
    std::cerr << "mygit: '" << command << "' is not implemented yet\n";
    return 1;
}

}  // namespace

int main(int argc, char** argv) {
    std::vector<std::string> args(argv + 1, argv + argc);

    if (args.empty() || args[0] == "-h" || args[0] == "--help") {
        print_usage();
        return args.empty() ? 1 : 0;
    }

    const std::string command = args[0];

    if (command == "init")         return not_implemented(command);
    if (command == "hash-object")  return not_implemented(command);
    if (command == "cat-file")     return not_implemented(command);
    if (command == "add")          return not_implemented(command);
    if (command == "status")       return not_implemented(command);
    if (command == "write-tree")   return not_implemented(command);
    if (command == "commit")       return not_implemented(command);
    if (command == "log")          return not_implemented(command);
    if (command == "branch")       return not_implemented(command);
    if (command == "checkout")     return not_implemented(command);

    std::cerr << "mygit: '" << command << "' is not a mygit command\n";
    return 1;
}
