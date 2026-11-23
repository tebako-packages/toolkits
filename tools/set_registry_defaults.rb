#!/usr/bin/env ruby
# frozen_string_literal: true

# set_registry_defaults.rb — move every recipe payload's `default:` in
# this feedstock's registry to the version a stable tag publish just
# published (each tool's own recipe version). Runs in the build-payload
# publish job, after `tebako publish`'s upserts and before the registry
# bot PR. The multi-payload counterpart of the single-payload
# set_registry_default pattern (one feedstock, many tools).
#
#   ruby tools/set_registry_defaults.rb
#
# WHY A FEEDSTOCK-SIDE STEP — the default-write lives in the product CLI,
# not here: tamatebako/tebako's crates/tebako-cli/src/publish.rs
# upsert_registry pins `default:` ONLY WHEN ABSENT, and no CLI verb moves
# an existing one. Only-when-absent is the right floor for a NEW package
# — the CLI cannot know a feedstock's release policy — but left alone it
# pins the default to the FIRST-EVER publish forever (the metanorma
# feedstock's issue #144: `default:` sat on an old line until a bare
# install resolved it against the current runtime line and the abi gate
# refused the composition). The feedstock's release policy: a STABLE tag
# publish IS the deliberate decision that moves the default — it tracks
# the just-published version, every publish, idempotently (a re-run of
# the same tag is a loud no-op). A prerelease-shaped tag never reaches
# here (the workflow's policy step gates it).
#
# GUARDS (named failures, never a silent guess — spec 00 §9): every
# recipe's payload entry must exist and must already CARRY the recipe's
# version row — the publish upserted it; a `default:` naming an absent
# row would break every bare resolve. The tool writes `default:` keys
# ONLY; `versions:` accumulation (older versions keep serving) stays the
# CLI upsert's territory.

require "yaml"

module SetRegistryDefaults
  # the named fail-closed error: a structural skew between the publish
  # step and the registry file — never a resolution guess
  class Error < StandardError; end

  # (name, version) per recipe, sorted for a stable report.
  def self.recipe_versions(recipes_dir)
    Dir.glob(File.join(recipes_dir, "*.yml")).sort.map do |f|
      doc = YAML.load_file(f)
      [doc.fetch("name"), doc.fetch("upstream").fetch("version")]
    end
  end

  def self.run(path, recipes_dir)
    reg = YAML.load_file(path)
    changed = false
    recipe_versions(recipes_dir).each do |name, version|
      entry = (reg["payloads"] || []).find { |p| p["name"] == name } or
        raise Error, "#{path}: no payloads entry named #{name} — the publish must upsert it before the default moves"
      carried = (entry["versions"] || []).map { |v| v["version"] }
      carried.include?(version) or
        raise Error, "#{path}: #{name} carries no #{version} row (carries: #{carried.join(' ')}) — `default:` never names a row the registry lacks"
      old = entry["default"]
      if old == version
        puts "#{name}: default already #{version} — nothing to move"
        next
      end
      entry["default"] = version
      puts "#{name}: default #{old || '(absent)'} → #{version}"
      changed = true
    end
    File.write(path, reg.to_yaml) if changed
    changed
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    SetRegistryDefaults.run("tpkg-registry.yaml", "recipes")
  rescue SetRegistryDefaults::Error => e
    abort "NAMED FAILURE: #{e.message}"
  end
end
