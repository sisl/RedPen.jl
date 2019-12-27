# RedPen: General submit script

# RedPen @info style printing (without newline)
macro sinfo(str)
    quote
        printstyled("[ RedPen: ", color=:red, bold=true)
        print($(esc(str)))
    end
end

# Input arguments:
#   args[1] = projectX.ext file, projectX/ directory, or status keyword
#   args[2] = email address of submitter
#   submit_func = course specific submit function

function submit(submit_func::Function, args::Vector{String})
    if length(args) >= 2
        yes::Bool = false
        project_data::String = args[1]
        email::String = args[2]
        nickname::String = email
        if length(args) == 3
            nickname = args[3]
        end

        if lowercase(project_data) == "status"
            @sinfo "Requesting status of submissions for $email...\n"
            yes = true
        else
            @sinfo "Would you like to submit $project_data? (y/n) "
            answer::String = readline()
            yes = (length(answer) > 0 && lowercase(answer)[1] == 'y')
        end

        yes ? submit_func(project_data, email, nickname) : @sinfo("Submission aborted.\n")
    else
        error("""
            USAGE: submit <FILE, DIRECTORY, or status> <EMAIL>
            Examples:
                submit project0.txt email@stanford.edu
                submit project1\\ email@stanford.edu
                submit project1\\ email@stanford.edu nickname
                submit status email@stanford.edu""")
    end
end