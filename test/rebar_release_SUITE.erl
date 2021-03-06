-module(rebar_release_SUITE).
-compile(export_all).
-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

all() -> [release,
          dev_mode_release,
          profile_dev_mode_override_release,
          tar,
          profile_ordering_sys_config_extend,
          profile_ordering_sys_config_extend_3_tuple_merge,
          extend_release,
          user_output_dir, profile_overlays,
          overlay_vars].

init_per_testcase(Case, Config0) ->
    Config = rebar_test_utils:init_rebar_state(Config0),
    Name = rebar_test_utils:create_random_name(atom_to_list(Case)),
    AppDir = ?config(apps, Config),
    application:load(rebar),

    ok = ec_file:mkdir_p(AppDir),
    State = rebar_state:new([{base_dir, filename:join([AppDir, "_build"])}]),

    rebar_test_utils:create_app(AppDir, Name, "1.0.0", [kernel, stdlib]),
    [{name, Name}, {apps, AppDir}, {state, State} | Config].

end_per_testcase(_, Config) ->
    meck:unload(),
    Config.

release(Config) ->
    AppDir = ?config(apps, Config),
    Name = ?config(name, Config),
    Vsn = "1.0.0",
    {ok, RebarConfig} =
        file:consult(rebar_test_utils:create_config(AppDir,
                                                    [{relx, [{release, {list_to_atom(Name), Vsn},
                                                              [list_to_atom(Name)]},
                                                             {lib_dirs, [AppDir]}]}])),
    rebar_test_utils:run_and_check(
      Config, RebarConfig,
      ["release"],
      {ok, [{release, list_to_atom(Name), Vsn, false}]}
     ).

dev_mode_release(Config) ->
    AppDir = ?config(apps, Config),
    Name = ?config(name, Config),
    Vsn = "1.0.0",
    {ok, RebarConfig} =
        file:consult(rebar_test_utils:create_config(AppDir,
                                                    [{relx, [{release, {list_to_atom(Name), Vsn},
                                                              [list_to_atom(Name)]},
                                                             {lib_dirs, [AppDir]},
                                                             {dev_mode, true}]}])),
    rebar_test_utils:run_and_check(
      Config, RebarConfig,
      ["release"],
      {ok, [{release, list_to_atom(Name), Vsn, true}]}
     ).


profile_dev_mode_override_release(Config) ->
    AppDir = ?config(apps, Config),
    Name = ?config(name, Config),
    Vsn = "1.0.0",
    {ok, RebarConfig} =
        file:consult(rebar_test_utils:create_config(AppDir,
                                                    [{relx, [{release, {list_to_atom(Name), Vsn},
                                                              [list_to_atom(Name)]},
                                                             {lib_dirs, [AppDir]},
                                                             {dev_mode, true}]},
                                                     {profiles,
                                                      [{ct,
                                                        [{relx, [{dev_mode, false}]}]}]}])),
    rebar_test_utils:run_and_check(
      Config, RebarConfig,
      ["as", "ct", "release"],
      {ok, [{release, list_to_atom(Name), Vsn, false}]}
     ).


tar(Config) ->
    AppDir = ?config(apps, Config),
    Name = ?config(name, Config),
    Vsn = "1.0.0",
    {ok, RebarConfig} =
        file:consult(rebar_test_utils:create_config(AppDir,
                                                    [{relx, [{release, {list_to_atom(Name), Vsn},
                                                              [list_to_atom(Name)]},
                                                             {lib_dirs, [AppDir]}]}])),
    rebar_test_utils:run_and_check(
      Config, RebarConfig,
      ["tar"],
      {ok, [{release, list_to_atom(Name), Vsn, false}, {tar, Name, Vsn}]}
     ).

%% Test that the order of release config args is not lost. If it is extend would fail.
extend_release(Config) ->
    AppDir = ?config(apps, Config),
    Name = ?config(name, Config),
    Vsn = "1.0.0",
    {ok, RebarConfig} =
        file:consult(rebar_test_utils:create_config(AppDir,
                                                    [{relx, [{release, {list_to_atom(Name), Vsn},
                                                              [list_to_atom(Name)]},
                                                             {release, {extended, Vsn, {extend, list_to_atom(Name)}},
                                                              []},
                                                             {lib_dirs, [AppDir]}]}])),
    rebar_test_utils:run_and_check(
      Config, RebarConfig,
      ["release", "-n", "extended"],
      {ok, [{release, extended, Vsn, false}]}
     ).

%% Ensure proper ordering of sys_config and extended releases in profiles
profile_ordering_sys_config_extend(Config) ->
    AppDir = ?config(apps, Config),
    Name = ?config(name, Config),
    Vsn = "1.0.0",
    TestSysConfig = filename:join(AppDir, "test.config"),
    OtherSysConfig = filename:join(AppDir, "other.config"),
    ok = file:write_file(TestSysConfig, "[]."),
    ok = file:write_file(OtherSysConfig, "[{some, content}]."),
    {ok, RebarConfig} =
        file:consult(rebar_test_utils:create_config(AppDir,
                                                    [{relx, [{release, {list_to_atom(Name), Vsn},
                                                              [list_to_atom(Name)]},
                                                             {sys_config, OtherSysConfig},
                                                             {lib_dirs, [AppDir]}]},
                                                     {profiles, [{extended,
                                                                 [{relx, [
                                                                         {sys_config, TestSysConfig}]}]}]}])),
    rebar_test_utils:run_and_check(
      Config, RebarConfig,
      ["as", "extended", "release"],
      {ok, [{release, list_to_atom(Name), Vsn, false}]}
     ),

    ReleaseDir = filename:join([AppDir, "./_build/extended/rel/", Name, "releases", Vsn]),
    {ok, [[]]} = file:consult(filename:join(ReleaseDir, "sys.config")).

%% test that tup_umerge works with tuples of different sizes
profile_ordering_sys_config_extend_3_tuple_merge(Config) ->
    AppDir = ?config(apps, Config),
    Name = ?config(name, Config),
    Vsn = "1.0.0",
    TestSysConfig = filename:join(AppDir, "test.config"),
    OtherSysConfig = filename:join(AppDir, "other.config"),
    ok = file:write_file(TestSysConfig, "[]."),
    ok = file:write_file(OtherSysConfig, "[{some, content}]."),
    {ok, RebarConfig} =
        file:consult(rebar_test_utils:create_config(AppDir,
                                                    [{relx, [{release, {list_to_atom(Name), Vsn},
                                                              [list_to_atom(Name)]},
                                                             {sys_config, OtherSysConfig},
                                                             {lib_dirs, [AppDir]}]},
                                                     {profiles, [{extended,
                                                                 [{relx, [
                                                                         {release, {extended, Vsn, {extend, list_to_atom(Name)}},
                                                                          []},
                                                                         {sys_config, TestSysConfig}]}]}]}])),

    rebar_test_utils:run_and_check(
      Config, RebarConfig,
      ["as", "extended", "release", "-n", Name],
      {ok, [{release, list_to_atom(Name), Vsn, false}]}
     ),

    ReleaseDir = filename:join([AppDir, "./_build/extended/rel/", Name, "releases", Vsn]),
    {ok, [[]]} = file:consult(filename:join(ReleaseDir, "sys.config")).

user_output_dir(Config) ->
    AppDir = ?config(apps, Config),
    Name = ?config(name, Config),
    ReleaseDir = filename:join(AppDir, "./_rel"),
    Vsn = "1.0.0",

    {ok, RebarConfig} =
        file:consult(rebar_test_utils:create_config(AppDir,
                                                    [{relx, [{release, {list_to_atom(Name), Vsn},
                                                              [list_to_atom(Name)]},
                                                             {lib_dirs, [AppDir]},
                                                             {dev_mode, true}]}])),
    rebar_test_utils:run_and_check(
      Config, RebarConfig,
      ["release", "-o", ReleaseDir],
      {ok, []}
     ),

    RelxState = rlx_state:new("", [], []),
    RelxState1 = rlx_state:base_output_dir(RelxState, ReleaseDir),
    {ok, RelxState2} = rlx_prv_app_discover:do(RelxState1),
    {ok, RelxState3} = rlx_prv_rel_discover:do(RelxState2),
    rlx_state:get_realized_release(RelxState3, list_to_atom(Name), Vsn).

profile_overlays(Config) ->
    AppDir = ?config(apps, Config),
    Name = ?config(name, Config),
    Vsn = "1.0.0",
    {ok, RebarConfig} =
        file:consult(rebar_test_utils:create_config(AppDir,
                                                    [{relx, [{release, {list_to_atom(Name), Vsn},
                                                              [list_to_atom(Name)]},
                                                             {overlay, [{mkdir, "randomdir"}]},
                                                             {lib_dirs, [AppDir]}]},
                                                    {profiles, [{prod, [{relx, [{overlay, [{mkdir, "otherrandomdir"}]}]}]}]}])),

    ReleaseDir = filename:join([AppDir, "./_build/prod/rel/", Name]),

    rebar_test_utils:run_and_check(
      Config, RebarConfig,
      ["as", "prod", "release"],
      {ok, [{release, list_to_atom(Name), Vsn, false},
            {dir, filename:join(ReleaseDir, "otherrandomdir")},
            {dir, filename:join(ReleaseDir, "randomdir")}]}
     ).

overlay_vars(Config) ->
    AppDir = ?config(apps, Config),
    Name = ?config(name, Config),
    Vsn = "1.0.0",
    {ok, RebarConfig} =
        file:consult(rebar_test_utils:create_config(AppDir,
                                                    [{relx, [{release, {list_to_atom(Name), Vsn},
                                                              [list_to_atom(Name)]},
                                                             {overlay, [
                                                                {template, filename:join([AppDir, "config/app.config"]),
                                                                  "releases/{{release_version}}/sys.config"}
                                                              ]},
                                                             {overlay_vars, filename:join([AppDir, "config/vars.config"])},
                                                             {lib_dirs, [AppDir]}]}
                                                    ])),

    ok = filelib:ensure_dir(filename:join([AppDir, "config", "dummy"])),

    OverlayVars = [{var_int, 1},
                   {var_string, "\"test\""},
                   {var_bin_string, "<<\"test\">>"},
                   {var_tuple, "{t, ['atom']}"},
                   {var_list, "[a, b, c, 'd']"},
                   {var_bin, "<<23, 24, 25>>"}],
    rebar_test_utils:create_config(AppDir,
                                   filename:join([AppDir, "config", "vars.config"]),
                                   OverlayVars),

    AppConfig = [[{var_int, {{var_int}}},
                  {var_string, {{{var_string}}}},
                  {var_bin_string, {{{var_bin_string}}}},
                  {var_tuple, {{{var_tuple}}}},
                  {var_list, {{{var_list}}}},
                  {var_bin, {{{var_bin}}}}]],
    rebar_test_utils:create_config(AppDir,
                                   filename:join([AppDir, "config", "app.config"]),
                                   AppConfig),

    rebar_test_utils:run_and_check(
      Config, RebarConfig,
      ["release"],
      {ok, [{release, list_to_atom(Name), Vsn, false}]}),

    %% now consult the sys.config file to make sure that is has the expected
    %% format
    ExpectedSysconfig = [{var_int, 1},
                         {var_string, "test"},
                         {var_bin_string, <<"test">>},
                         {var_tuple, {t, ['atom']}},
                         {var_list, [a, b, c, 'd']},
                         {var_bin, <<23, 24, 25>>}],
    {ok, [ExpectedSysconfig]} = file:consult(filename:join([AppDir, "_build/default/rel",
                                                          Name, "releases", Vsn, "sys.config"])).
