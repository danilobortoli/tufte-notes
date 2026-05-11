// Tufte Notes editor — a tiny contenteditable bridge with live Markdown
// transforms and a Markdown <-> HTML round-trip serializer.

(function () {
    const editor = document.getElementById("editor");
    let suppressSave = false;
    let saveTimer = null;

    function send(markdown) {
        if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.save) {
            return;
        }
        window.webkit.messageHandlers.save.postMessage(markdown);
    }

    function scheduleSave() {
        if (suppressSave) return;
        if (saveTimer) clearTimeout(saveTimer);
        saveTimer = setTimeout(() => {
            const md = htmlToMarkdown(editor);
            send(md);
        }, 350);
    }

    // ---------- Markdown -> HTML ----------

    function escapeHtml(s) {
        return s
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
    }

    function inline(s) {
        // Sidenotes: ^[text] -> <span class="sidenote">text</span>
        s = s.replace(/\^\[([^\]]+)\]/g, (_, t) => {
            return '<span class="sidenote" contenteditable="true">' + escapeHtml(t) + "</span>";
        });
        // Inline code: `code`
        s = s.replace(/`([^`]+)`/g, (_, t) => "<code>" + escapeHtml(t) + "</code>");
        // Bold: **text**
        s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
        // Italic: *text*
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

            // Paragraph: collect contiguous non-empty lines
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
                if (tag === "strong" || tag === "b") {
                    out += "**" + inlineToMd(n) + "**";
                } else if (tag === "em" || tag === "i") {
                    out += "*" + inlineToMd(n) + "*";
                } else if (tag === "code") {
                    out += "`" + n.textContent + "`";
                } else if (tag === "br") {
                    out += "\n";
                } else if (n.classList && n.classList.contains("sidenote")) {
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
            } else if (tag === "p" || tag === "div") {
                const text = inlineToMd(n).trim();
                if (text) parts.push(text);
            } else {
                const text = inlineToMd(n).trim();
                if (text) parts.push(text);
            }
        });
        return parts.join("\n\n") + "\n";
    }

    // ---------- Live Markdown transforms (Medium-style) ----------

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

    function replaceBlock(block, newHtml) {
        const tmp = document.createElement("div");
        tmp.innerHTML = newHtml;
        const newBlock = tmp.firstElementChild;
        block.parentNode.replaceChild(newBlock, block);
        const range = document.createRange();
        range.selectNodeContents(newBlock);
        range.collapse(false);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
    }

    function tryShortcut() {
        const block = getCurrentBlock();
        if (!block) return;
        if (block.tagName.toLowerCase() !== "p" && block.tagName.toLowerCase() !== "div") return;

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
            // Add a fresh paragraph after the hr so the user can keep typing.
            const p = document.createElement("p");
            p.innerHTML = "<br>";
            editor.appendChild(p);
        }
    }

    editor.addEventListener("input", (e) => {
        if (e.inputType === "insertText" && e.data === " ") {
            tryShortcut();
        }
        scheduleSave();
    });

    // Inline sidenote: typing ^[text] anywhere should convert when closed.
    editor.addEventListener("input", () => {
        const block = getCurrentBlock();
        if (!block) return;
        const html = block.innerHTML;
        if (/\^\[[^\]]+\]/.test(html)) {
            const replaced = html.replace(/\^\[([^\]]+)\]/g,
                '<span class="sidenote" contenteditable="true">$1</span>');
            if (replaced !== html) {
                block.innerHTML = replaced;
                // Put cursor at the end of the block.
                const range = document.createRange();
                range.selectNodeContents(block);
                range.collapse(false);
                const sel = window.getSelection();
                sel.removeAllRanges();
                sel.addRange(range);
            }
        }
    });

    // Ensure Enter creates a fresh <p> after headings instead of duplicating them.
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
            // Place cursor at end so typing continues the document.
            const range = document.createRange();
            range.selectNodeContents(editor);
            range.collapse(false);
            const sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(range);
        }
    };
})();
