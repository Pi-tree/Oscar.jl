using Documenter, Oscar, DocumenterMarkdown

import Documenter:
    Anchors,
    DocTests,
    Documents,
    Documenter,
    Utilities

import Documenter.Utilities: Selectors

using Documenter.Builder
import Documenter.Builder: SetupBuildDirectory, walk_navpages
import Documenter.Documents: Document, Page

function Selectors.runner(::Type{SetupBuildDirectory}, doc::Documents.Document)
    @info "SetupBuildDirectory: setting up build directory."

    # Frequently used fields.
    build  = doc.user.build
    source = doc.user.source
    workdir = doc.user.workdir

    # The .user.source directory must exist.
    isdir(source) || error("source directory '$(abspath(source))' is missing.")

    # We create the .user.build directory.
    # If .user.clean is set, we first clean the existing directory.
    doc.user.clean && isdir(build) && rm(build; recursive = true)
    isdir(build) || mkpath(build)

    # We'll walk over all the files in the .user.source directory.
    # The directory structure is copied over to .user.build. All files, with
    # the exception of markdown files (identified by the extension) are copied
    # over as well, since they're assumed to be images, data files etc.
    # Markdown files, however, get added to the document and also stored into
    # `mdpages`, to be used later.
    mdpages = String[]
    for (root, dirs, files) in walkdir(source)
        for dir in dirs
            d = normpath(joinpath(build, relpath(root, source), dir))
            isdir(d) || mkdir(d)
        end
        for file in files
            src = normpath(joinpath(root, file))
            dst = normpath(joinpath(build, relpath(root, source), file))

            if workdir == :build
                # set working directory to be the same as `build`
                wd = normpath(joinpath(build, relpath(root, source)))
            elseif workdir isa Symbol
                # Maybe allow `:src` and `:root` as well?
                throw(ArgumentError("Unrecognized working directory option '$workdir'"))
            else
                wd = normpath(joinpath(doc.user.root, workdir))
            end

            if endswith(file, ".md")
                push!(mdpages, Utilities.srcpath(source, root, file))
                Documents.addpage!(doc, src, dst, wd)
            else
                cp(src, dst; force = true)
            end
        end
    end

    for extra in ["Hecke", "Nemo", "AbstractAlgebra"]
        for (root, dirs, files) in walkdir(normpath(joinpath(dirname(pathof(getproperty(Main, Symbol(extra)))), "..", "docs", "src")))
            for dir in dirs
                d = normpath(joinpath(build, relpath(root, source), dir))
                isdir(d) || mkdir(d)
            end
            for file in files
                src = normpath(joinpath(root, file))
                dst = normpath(joinpath(build, relpath(root, source), file))

                if workdir == :build
                    # set working directory to be the same as `build`
                    wd = normpath(joinpath(build, relpath(root, source)))
                elseif workdir isa Symbol
                    # Maybe allow `:src` and `:root` as well?
                    throw(ArgumentError("Unrecognized working directory option '$workdir'"))
                else
                    wd = normpath(joinpath(doc.user.root, workdir))
                end

                if endswith(file, ".md")
                    push!(mdpages, Utilities.srcpath(source, root, file))
                    Documents.addpage!(doc, src, dst, wd, extra)
                end
            end
        end
    end


    # If the user hasn't specified the page list, then we'll just default to a
    # flat list of all the markdown files we found, sorted by the filesystem
    # path (it will group them by subdirectory, among others).
    userpages = isempty(doc.user.pages) ? sort(mdpages, lt=lt_page) : doc.user.pages

    # Populating the .navtree and .navlist.
    # We need the for loop because we can't assign to the fields of the immutable
    # doc.internal.
    for navnode in walk_navpages(userpages, nothing, doc)
        push!(doc.internal.navtree, navnode)
    end

    # Finally we populate the .next and .prev fields of the navnodes that point
    # to actual pages.
    local prev::Union{Documents.NavNode, Nothing} = nothing
    for navnode in doc.internal.navlist
        navnode.prev = prev
        if prev !== nothing
            prev.next = navnode
        end
        prev = navnode
    end
end

function Documenter.Documents.addpage!(doc::Document, src::AbstractString, dst::AbstractString, wd::AbstractString, trunc::AbstractString)
    page = Page(src, dst, wd)
    # page's identifier is the path relative to the `doc.user.source` directory
    name = normpath(relpath(src, doc.user.source))
    if occursin(trunc, name)
      name = replace(name, Regex(".*$(trunc)") => trunc)
    end
    doc.blueprint.pages[name] = page
end



const hecke = joinpath("Hecke", "docs", "src")
const aa = joinpath("AbstractAlgebra", "docs", "src")
const nemo = joinpath("Nemo", "docs", "src")
makedocs(
         format   = Documenter.HTML(),
#         format   = Markdown(),
         sitename = "Oscar.jl",
         modules = [Oscar, Hecke, Nemo, AbstractAlgebra],
         clean = true,
         doctest = false,
         pages    = [
             "index.md",
             "Rings" => [ "$(aa)/rings.md",
                          "Rings/integer.md",
                          "Univariate Polynomials" => [
                            "$(aa)/polynomial_rings.md",
                            "$(aa)/polynomial.md"],
                          "Multivariate Polynomials" => [
                            "$(aa)/mpolynomial_rings.md",
                            "$(aa)/mpolynomial.md"],
                          "Orders" => [
                            "$(hecke)/orders/introduction.md",
                            "$(hecke)/orders/orders.md",
                            "$(hecke)/orders/elements.md",
                            "$(hecke)/orders/ideals.md",
                            "$(hecke)/orders/frac_ideals.md"],
                          "Series Rings" => [
                              "$(aa)/series_rings.md",
                              "$(aa)/series.md",
                              "$(aa)/puiseux.md",
                              "$(nemo)/series.md",
                              "$(nemo)/puiseux.md"],
                         ],
             "Fields" => [            
                          "$(aa)/fields.md",
			  "Rings/rational.md",
                          "Number Fields" => [
                            "$(hecke)/number_fields/intro.md",
                            "$(hecke)/number_fields/basics.md",
                            "$(hecke)/number_fields/elements.md"],
                          "$(hecke)/FacElem.md",
                          "$(hecke)/class_fields/intro.md",
                          "$(aa)/fields.md",
                          "$(aa)/fraction_fields.md",
                          "$(aa)/fraction.md",
                          "Local Fields" => [
                              "$(nemo)/padic.md",
                              "$(nemo)/qadic.md"],
                          "$(nemo)/finitefield.md",    
                         ],
             "Groups" => [ "Groups/groups.md",
                           "$(hecke)/abelian/introduction.md"
                         ],
             "Linear Algebra" => [ "$(hecke)/sparse/intro.md",
                                   "$(aa)/matrix_spaces.md",
                                   "$(aa)/matrix.md",
                                   "$(aa)/matrix_algebras.md",
                     "Modules" => ["$(aa)/module.md",
                                    "$(aa)/free_module.md",
                                    "$(aa)/submodule.md",
                                    "$(aa)/quotient_module.md",
                                    "$(aa)/direct_sum.md",
                                    "$(aa)/module_homomorphism.md"],
                     "Quadratic and Hermitian forms" => [
                                   "$(hecke)/quad_forms/introduction.md",
                                   "$(hecke)/quad_forms/basics.md",
                                   "$(hecke)/quad_forms/lattices.md"],
                           ],

         ]
)

#deploydocs(
#   julia = "1.3",
#   repo   = "github.com/oscar-system/Oscar.jl.git",
#   target = "build",
#   deps = nothing,
#   make   = nothing,
#   osname = "linux"
#)

deploydocs(
   repo   = "github.com/oscar-system/Oscar.jl.git",
#  deps = Deps.pip("pymdown-extensions", "pygments", "mkdocs", "python-markdown-math", "mkdocs-material", "mkdocs-cinder"),
   deps = nothing,
   target = "build",
#  make = () -> run(`mkdocs build`),
   make = nothing
)
