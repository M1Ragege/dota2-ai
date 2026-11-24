"use strict";

let teams = [];
let selectedRadiant = "";
let selectedDire = "";
let locked = false;
let receivedList = false;

function findLabel(folder) {
    for (let i = 0; i < teams.length; i++) {
        if (teams[i].folder === folder) return teams[i].label;
    }
    return folder || "—";
}

function updatePreview() {
    const preview = $("#MatchupPreview");
    if (!preview) return;
    if (!teams.length) {
        preview.text = "Нет доступных команд в AVAILABLE_TEAMS";
        return;
    }
    preview.text = `${findLabel(selectedRadiant)}  VS  ${findLabel(selectedDire)}`;
}

function renderList(containerId, side) {
    const container = $("#" + containerId);
    if (!container) return;
    container.RemoveAndDeleteChildren();

    const selected = side === "radiant" ? selectedRadiant : selectedDire;
    const activeClass = side === "radiant" ? "SelectedRadiant" : "SelectedDire";

    for (let i = 0; i < teams.length; i++) {
        const team = teams[i];
        const btn = $.CreatePanel("Button", container, `${side}_${team.folder}`);
        btn.AddClass("TeamOption");
        if (team.folder === selected) {
            btn.AddClass(activeClass);
        }

        const nameLbl = $.CreatePanel("Label", btn, "");
        nameLbl.AddClass("TeamName");
        nameLbl.text = team.label;

        const folderLbl = $.CreatePanel("Label", btn, "");
        folderLbl.AddClass("TeamFolder");
        folderLbl.text = "teams/" + team.folder;

        btn.SetPanelEvent("onactivate", () => {
            if (locked) return;
            if (side === "radiant") {
                selectedRadiant = team.folder;
            } else {
                selectedDire = team.folder;
            }
            renderAll();
        });
    }
}

function renderAll() {
    renderList("RadiantList", "radiant");
    renderList("DireList", "dire");
    updatePreview();

    const startBtn = $("#StartButton");
    if (startBtn) {
        startBtn.enabled = !locked && selectedRadiant !== "" && selectedDire !== "";
    }
}

function OnSwapSides() {
    if (locked) return;
    const tmp = selectedRadiant;
    selectedRadiant = selectedDire;
    selectedDire = tmp;
    renderAll();
}

function OnRandomMatchup() {
    if (locked || teams.length === 0) return;
    const i1 = Math.floor(Math.random() * teams.length);
    let i2 = Math.floor(Math.random() * teams.length);
    if (teams.length > 1) {
        while (i2 === i1) {
            i2 = Math.floor(Math.random() * teams.length);
        }
    }
    selectedRadiant = teams[i1].folder;
    selectedDire = teams[i2].folder;
    renderAll();
}

function OnStartMatch() {
    if (locked || !selectedRadiant || !selectedDire) return;
    locked = true;
    renderAll();
    GameEvents.SendCustomGameEventToServer("tournament_select_matchup", {
        radiant: selectedRadiant,
        dire: selectedDire,
    });
}

function OnTeamsList(data) {
    receivedList = true;
    teams = [];
    if (data && data.teams) {
        const keys = Object.keys(data.teams).sort((a, b) => Number(a) - Number(b));
        for (let i = 0; i < keys.length; i++) {
            const item = data.teams[keys[i]];
            if (item && item.folder) {
                teams.push({
                    folder: String(item.folder),
                    label: String(item.label || item.folder),
                });
            }
        }
    }

    if (!selectedRadiant && data && data.defaultRadiant) {
        selectedRadiant = String(data.defaultRadiant);
    } else if (!selectedRadiant && teams.length > 0) {
        selectedRadiant = teams[0].folder;
    }

    if (!selectedDire && data && data.defaultDire) {
        selectedDire = String(data.defaultDire);
    } else if (!selectedDire && teams.length > 0) {
        selectedDire = teams[Math.min(1, teams.length - 1)].folder;
    }

    renderAll();
}

function OnSetupStatus(data) {
    const lbl = $("#StatusLabel");
    if (!lbl || !data) return;

    lbl.text = data.message || "";
    lbl.SetHasClass("Error", data.state === "error");

    if (data.state === "error") {
        locked = false;
        renderAll();
    } else if (data.state === "loading" || data.state === "launching") {
        locked = true;
        const startBtn = $("#StartButton");
        if (startBtn) startBtn.enabled = false;
    }
}

function requestTeamsLoop() {
    if (receivedList) return;
    GameEvents.SendCustomGameEventToServer("tournament_ui_ready", {});
    $.Schedule(0.5, requestTeamsLoop);
}

(function () {
    GameEvents.Subscribe("tournament_teams_list", OnTeamsList);
    GameEvents.Subscribe("tournament_setup_status", OnSetupStatus);
    requestTeamsLoop();
})();
