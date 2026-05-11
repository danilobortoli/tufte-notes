// Tufte Notes editor — Markdown <-> HTML bridge for the contenteditable
// surface, plus format actions and find driven from the SwiftUI shell.

(function () {
    const editor = document.getElementById("editor");
    let suppressSave = false;
    let saveTimer = null;

    function send(name, payload) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[name]) {
            window.webkit.messageHandlers[name].postMessage(payload);
        }
    }

    function scheduleSave() {
        if (suppressSave) return;
        if (saveTimer) clearTimeout(saveTimer);
        saveTimer = setTimeout(() => {
            send("save", htmlToMarkdown(editor));
            sendStats();
        }, 350);
    }

    function sendStats() {
        const text = editor.innerText || "";
        const words = text.split(/\s+/).filter(Boolean).length;
        const chars = text.length;
        send("stats", { words, chars });
    }

    // ---------- Markdown -> HTML ----------

    function escapeHtml(s) {
        return s
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
    }

    function inline(s) {
        s = s.replace(/\^\[([^\]]+)\]/g, (_, t) => {
            return '<span class="sidenote" contenteditable="true">' + escapeHtml(t) + "</span>";
        });
        s = s.replace(/`([^`]+)`/g, (_, t) => "<code>" + escapeHtml(t) + "</code>");
        s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
        s = s.replace(/(^|[^*])\*([^*\n]+)\*/g, "$1<em>$2</em>");
        return s;
    }

    function markdownToHtml(md) {
        const lines = md.split(/\r?\n/);
        const out = [];
        let i = 0;

        while (i < lines.length) {
            const line = lines[i];
            if (/^\s*$/.test(line)) { i++; continue; }
            if (/^---\s*$/.test(line)) { out.push("<hr>"); i++; continue; }

            let m;
            if ((m = line.match(/^(#{1,3})\s+(.*)$/))) {
                const level = m[1].length;
                out.push(`<h${level}>${inline(escapeHtml(m[2]))}</h${level}>`);
                i++;
                continue;
            }

            if (/^>\s?/.test(line)) {
                const buf = [];
                while (i < lines.length && /^>\s?/.test(lines[i])) {
                    buf.push(lines[i].replace(/^>\s?/, ""));
                    i++;
                }
                out.push("<blockquote><p>" + inline(escapeHtml(buf.join(" "))) + "</p></blockquote>");
                continue;
            }

            if (/^[-*]\s+/.test(line)) {
                const buf = [];
                while (i < lines.length && /^[-*]\s+/.test(lines[i])) {
                    buf.push(lines[i].replace(/^[-*]\s+/, ""));
                    i++;
                }
                out.push("<ul>" + buf.map(b => "<li>" + inline(escapeHtml(b)) + "</li>").join("") + "</ul>");
                continue;
            }

            if (/^\d+\.\s+/.test(line)) {
                const buf = [];
                while (i < lines.length && /^\d+\.\s+/.test(lines[i])) {
                    buf.push(lines[i].replace(/^\d+\.\s+/, ""));
                    i++;
                }
                out.push("<ol>" + buf.map(b => "<li>" + inline(escapeHtml(b)) + "</li>").join("") + "</ol>");
                continue;
            }

            if (/^```/.test(line)) {
                const buf = [];
                i++;
                while (i < lines.length && !/^```/.test(lines[i])) {
                    buf.push(lines[i]);
                    i++;
                }
                if (i < lines.length) i++;
                out.push("<pre><code>" + escapeHtml(buf.join("\n")) + "</code></pre>");
                continue;
            }

            const buf = [];
            while (i < lines.length && !/^\s*$/.test(lines[i])
                && !/^(#{1,3})\s+/.test(lines[i])
                && !/^>\s?/.test(lines[i])
                && !/^[-*]\s+/.test(lines[i])
                && !/^\d+\.\s+/.test(lines[i])
                && !/^---\s*$/.test(lines[i])
                && !/^```/.test(lines[i])) {
                buf.push(lines[i]);
                i++;
            }
            out.push("<p>" + inline(escapeHtml(buf.join(" "))) + "</p>");
        }

        return out.join("\n");
    }

    // ---------- HTML -> Markdown ----------

    function inlineToMd(node) {
        let out = "";
        node.childNodes.forEach((n) => {
            if (n.nodeType === Node.TEXT_NODE) {
                out += n.textContent;
            } else if (n.nodeType === Node.ELEMENT_NODE) {
                const tag = n.tagName.toLowerCase();
                if (tag === "strong" || tag === "b") out += "**" + inlineToMd(n) + "**";
                else if (tag === "em" || tag === "i") out += "*" + inlineToMd(n) + "*";
                else if (tag === "code") out += "`" + n.textContent + "`";
                else if (tag === "br") out += "\n";
                else if (tag === "mark" && n.classList.contains("tufte-find")) out += inlineToMd(n);
                else if (n.classList && n.classList.contains("sidenote")) {
                    out += "^[" + n.textContent.trim() + "]";
                } else {
                    out += inlineToMd(n);
                }
            }
        });
        return out;
    }

    function htmlToMarkdown(root) {
        const parts = [];
        root.childNodes.forEach((n) => {
            if (n.nodeType !== Node.ELEMENT_NODE) {
                const text = (n.textContent || "").trim();
                if (text) parts.push(text);
                return;
            }
            const tag = n.tagName.toLowerCase();
            if (tag === "h1") parts.push("# " + inlineToMd(n));
            else if (tag === "h2") parts.push("## " + inlineToMd(n));
            else if (tag === "h3") parts.push("### " + inlineToMd(n));
            else if (tag === "hr") parts.push("---");
            else if (tag === "blockquote") {
                const inner = inlineToMd(n).trim();
                parts.push(inner.split(/\n+/).map(l => "> " + l).join("\n"));
            } else if (tag === "ul") {
                const items = [];
                n.querySelectorAll(":scope > li").forEach(li => items.push("- " + inlineToMd(li).trim()));
                parts.push(items.join("\n"));
            } else if (tag === "ol") {
                const items = [];
                n.querySelectorAll(":scope > li").forEach((li, idx) => items.push((idx + 1) + ". " + inlineToMd(li).trim()));
                parts.push(items.join("\n"));
            } else if (tag === "pre") {
                parts.push("```\n" + n.textContent + "\n```");
            } else {
                const text = inlineToMd(n).trim();
                if (text) parts.push(text);
            }
        });
        return parts.join("\n\n") + "\n";
    }

    // ---------- Live shortcuts ----------

    function getCurrentBlock() {
        const sel = window.getSelection();
        if (!sel || sel.rangeCount === 0) return null;
        let node = sel.anchorNode;
        while (node && node !== editor) {
            if (node.parentNode === editor) return node;
            node = node.parentNode;
        }
        return null;
    }

    function replaceBlock(block, newHtml, putCursorAtEnd = true) {
        const tmp = document.createElement("div");
        tmp.innerHTML = newHtml;
        const newBlock = tmp.firstElementChild;
        block.parentNode.replaceChild(newBlock, block);
        const range = document.createRange();
        range.selectNodeContents(newBlock);
        range.collapse(!putCursorAtEnd ? true : false);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
        return newBlock;
    }

    function tryShortcut() {
        const block = getCurrentBlock();
        if (!block) return;
        const tag = block.tagName.toLowerCase();
        if (tag !== "p" && tag !== "div") return;

        const text = block.textContent;
        let m;
        if ((m = text.match(/^(#{1,3})\s(.*)$/))) {
            const level = m[1].length;
            replaceBlock(block, `<h${level}>${escapeHtml(m[2])}</h${level}>`);
        } else if ((m = text.match(/^[-*]\s(.*)$/))) {
            replaceBlock(block, `<ul><li>${escapeHtml(m[1])}</li></ul>`);
        } else if ((m = text.match(/^>\s(.*)$/))) {
            replaceBlock(block, `<blockquote><p>${escapeHtml(m[1])}</p></blockquote>`);
        } else if (text === "---") {
            replaceBlock(block, `<hr>`);
            const p = document.createElement("p");
            p.innerHTML = "<br>";
            editor.appendChild(p);
        }
    }

    // ---------- Format actions (called from SwiftUI) ----------

    function wrapInline(tag, className) {
        const sel = window.getSelection();
        if (!sel || sel.rangeCount === 0) return;
        const range = sel.getRangeAt(0);
        if (range.collapsed) {
            const el = document.createElement(tag);
            if (className) el.className = className;
            el.textContent = className === "sidenote" ? "nota lateral" : "texto";
            range.insertNode(el);
            const r = document.createRange();
            r.selectNodeContents(el);
            sel.removeAllRanges();
            sel.addRange(r);
        } else {
            const content = range.extractContents();
            const el = document.createElement(tag);
            if (className) el.className = className;
            el.appendChild(content);
            range.insertNode(el);
            const r = document.createRange();
            r.selectNodeContents(el);
            sel.removeAllRanges();
            sel.addRange(r);
        }
    }

    function setBlock(tagName) {
        const block = getCurrentBlock();
        if (!block) return;
        const html = block.innerHTML;
        replaceBlock(block, `<${tagName}>${html}</${tagName}>`);
    }

    function format(action) {
        switch (action) {
            case "bold":
                document.execCommand("bold");
                break;
            case "italic":
                document.execCommand("italic");
                break;
            case "code":
                wrapInline("code", null);
                break;
            case "h1": setBlock("h1"); break;
            case "h2": setBlock("h2"); break;
            case "h3": setBlock("h3"); break;
            case "ul":
                document.execCommand("insertUnorderedList");
                break;
            case "ol":
                document.execCommand("insertOrderedList");
                break;
            case "quote":
                document.execCommand("formatBlock", false, "blockquote");
                break;
            case "hr":
                document.execCommand("insertHorizontalRule");
                break;
            case "sidenote":
                wrapInline("span", "sidenote");
                break;
        }
        scheduleSave();
    }

    // ---------- Find ----------

    let findMatches = [];
    let findIndex = -1;
    let findQuery = "";

    function clearFind() {
        editor.querySelectorAll("mark.tufte-find").forEach((m) => {
            const parent = m.parentNode;
            while (m.firstChild) parent.insertBefore(m.firstChild, m);
            parent.removeChild(m);
            parent.normalize();
        });
        findMatches = [];
        findIndex = -1;
        findQuery = "";
    }

    function highlightAll(query) {
        clearFind();
        if (!query) return;
        const q = query.toLowerCase();
        const walker = document.createTreeWalker(editor, NodeFilter.SHOW_TEXT, null);
        const nodes = [];
        while (walker.nextNode()) nodes.push(walker.currentNode);

        nodes.forEach((node) => {
            const text = node.textContent;
            const lower = text.toLowerCase();
            let idx = 0, start;
            const pieces = [];
            while ((start = lower.indexOf(q, idx)) !== -1) {
                if (start > idx) pieces.push(document.createTextNode(text.slice(idx, start)));
                const mark = document.createElement("mark");
                mark.className = "tufte-find";
                mark.textContent = text.slice(start, start + q.length);
                pieces.push(mark);
                idx = start + q.length;
            }
            if (pieces.length) {
                if (idx < text.length) pieces.push(document.createTextNode(text.slice(idx)));
                const frag = document.createDocumentFragment();
                pieces.forEach((p) => frag.appendChild(p));
                node.parentNode.replaceChild(frag, node);
            }
        });

        findMatches = Array.from(editor.querySelectorAll("mark.tufte-find"));
        findIndex = findMatches.length > 0 ? 0 : -1;
        focusCurrent();
    }

    function focusCurrent() {
        findMatches.forEach((m) => m.classList.remove("current"));
        if (findIndex >= 0 && findIndex < findMatches.length) {
            const el = findMatches[findIndex];
            el.classList.add("current");
            el.scrollIntoView({ block: "center", behavior: "smooth" });
        }
    }

    function findNext() {
        if (findMatches.length === 0) return;
        findIndex = (findIndex + 1) % findMatches.length;
        focusCurrent();
    }

    function findPrev() {
        if (findMatches.length === 0) return;
        findIndex = (findIndex - 1 + findMatches.length) % findMatches.length;
        focusCurrent();
    }

    // ---------- Theme & font ----------

    function setTheme(theme) {
        document.documentElement.classList.remove("light", "dark");
        if (theme === "light" || theme === "dark") {
            document.documentElement.classList.add(theme);
        }
    }

    function setFontSize(rem) {
        document.documentElement.style.setProperty("--font-size", rem + "rem");
    }

    // ---------- Events ----------

    editor.addEventListener("input", (e) => {
        if (e.inputType === "insertText" && e.data === " ") {
            tryShortcut();
        }
        const block = getCurrentBlock();
        if (block) {
            const html = block.innerHTML;
            if (/\^\[[^\]]+\]/.test(html)) {
                const replaced = html.replace(/\^\[([^\]]+)\]/g,
                    '<span class="sidenote" contenteditable="true">$1</span>');
                if (replaced !== html) {
                    block.innerHTML = replaced;
                    const range = document.createRange();
                    range.selectNodeContents(block);
                    range.collapse(false);
                    const sel = window.getSelection();
                    sel.removeAllRanges();
                    sel.addRange(range);
                }
            }
        }
        scheduleSave();
    });

    editor.addEventListener("keydown", (e) => {
        if (e.key !== "Enter" || e.shiftKey) return;
        const block = getCurrentBlock();
        if (!block) return;
        const tag = block.tagName.toLowerCase();
        if (["h1", "h2", "h3", "blockquote"].includes(tag)) {
            e.preventDefault();
            const p = document.createElement("p");
            p.innerHTML = "<br>";
            block.after(p);
            const range = document.createRange();
            range.selectNodeContents(p);
            range.collapse(true);
            const sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(range);
            scheduleSave();
        }
    });

    // ---------- API exposed to Swift ----------

    window.tufte = {
        load(markdown) {
            suppressSave = true;
            editor.innerHTML = markdownToHtml(markdown || "");
            suppressSave = false;
            const range = document.createRange();
            range.selectNodeContents(editor);
            range.collapse(false);
            const sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(range);
            sendStats();
        },
        format,
        setTheme,
        setFontSize,
        find: highlightAll,
        findNext,
        findPrev,
        clearFind,
    };
})();
