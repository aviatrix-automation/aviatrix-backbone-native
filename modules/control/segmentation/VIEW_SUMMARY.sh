#!/bin/bash
# Quick script to view segmentation summary table
# Usage: ./VIEW_SUMMARY.sh

echo ""
terraform output -raw summary_table
echo ""
